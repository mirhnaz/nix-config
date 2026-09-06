-- Declarative startup session for Omarchy / Hyprland (scrolling OR dwindle).
--
-- On every Hyprland start the apps in SESSION are launched ONE AT A TIME.
-- Each step waits for its window to open (matched by class) and places it.
-- The layout in effect on WORKSPACE (general.layout / a workspace layout rule)
-- is detected at run time, so switching between scrolling and dwindle in
-- looknfeel.lua needs no change here.
--
--   scrolling  every non-stack item becomes a new column, left→right, with
--              `width` as a fraction of the monitor (overflow is fine — the
--              layout scrolls). Width is applied through a temporary window
--              rule (scrolling_width) that exists only while that app is being
--              launched. "stack" moves the new window into the column to its
--              left, i.e. under the window placed just before it.
--   dwindle    everything has to fit on screen, so columns are opened first
--              (each split to the right of the previous one via the dwindle
--              "preselect" layout message), then stacked items are split below
--              their column head. Widths are scaled down proportionally if they
--              add up to more than 1.0; the last column takes whatever is left.
--   other      (master, …) apps are just launched in order on WORKSPACE.
--
-- Launching sequentially is what makes the column order deterministic.
-- On scrolling nothing depends on keyboard focus; on dwindle a new window
-- always splits the focused window, so the script focuses the right one
-- before each launch.
--
-- This recreates windows only. In-app state (Chromium tabs, the VS Code
-- folder, shell history) is up to each app's own restore setting.
--
-- Edit SESSION to change the layout. Table order = column order, left→right.
--   cmd         shell command that opens the window
--   class       exact window class to wait for  (hyprctl -j clients | jq -r '.[].class')
--   width       column width as a fraction of the monitor (0.1 – 1.0), either a
--               number or a per-layout table: { scrolling = 0.33, dwindle = 0.25 }
--   stack       true = put this window below the previous column's window
--   timeout_ms  optional per-app override of STEP_TIMEOUT_MS
--
-- Manual run on an EMPTY workspace (testing):   hyprctl eval "omarchy_session.restore(9)"

local SESSION = {
  { cmd = "omarchy-launch-terminal", class = "com.mitchellh.ghostty", width = 0.33 },
  { cmd = "omarchy-launch-tui btop", class = "org.omarchy.btop", stack = true },
  { cmd = "uwsm-app -- code", class = "code", width = 0.43 },
  { cmd = "omarchy-launch-browser", class = "chromium", width = 0.49 },
  {
    cmd = "uwsm-app -- chromium --profile-directory=Default --app-id=fmpnliohjhemenmnlpbfagaolkdacoja",
    class = "chrome-fmpnliohjhemenmnlpbfagaolkdacoja-Default",
    width = 0.49,
  },
  { cmd = "uwsm-app -- chatgpt", class = "chatgpt", stack = true },
}

local WORKSPACE = 1 -- workspace id to build the session on
local START_DELAY_MS = 2000 -- let Omarchy's own start hooks (env import, shell) finish first
local STEP_TIMEOUT_MS = 20000 -- give up on an app that never opens a window
local SETTLE_MS = 150 -- let the layout place a new window before moving it
local WIDTH_TOLERANCE_PX = 20 -- re-apply a column width only if it is off by more than this

-- ---------------------------------------------------------------------------

local function fresh_state()
  return {
    running = false,
    workspace = WORKSPACE,
    layout = "scrolling", -- "scrolling" | "dwindle" | "other", detected in start()
    width_scale = 1, -- dwindle: factor that makes the column widths fit on screen
    queue = {},
    pending = nil,
    rule = nil,
    sub = nil,
    timer = nil,
    settle = nil,
    first = nil,
    placed = {},
    windows = {}, -- SESSION item -> its window, once placed
    last_column = nil, -- window of the most recently placed column (dwindle)
    done = 0,
    skipped = 0,
  }
end

local state = fresh_state()

local function notify(text, icon, timeout)
  hl.notification.create({ text = "Session: " .. text, timeout = timeout or 4000, icon = icon or "ok" })
end

local function stop_timer(name)
  local t = state[name]
  if t then
    pcall(function()
      t:set_enabled(false)
    end)
    state[name] = nil
  end
end

local function drop_rule()
  if state.rule then
    pcall(function()
      state.rule:set_enabled(false)
    end)
    state.rule = nil
  end
end

local function regex_escape(text)
  -- Window-rule matches are regular expressions; escape the class literally.
  return (text:gsub("[%.%-%+%*%?%(%)%[%]%^%$%|\\]", "\\%0"))
end

-- Layout in effect on the session workspace: a workspace layout rule wins over
-- general.layout. Anything that is not scrolling/dwindle is treated as "other".
local function detect_layout(workspace)
  local name
  local ok, ws = pcall(hl.get_workspace, workspace)
  if ok and ws and type(ws.tiled_layout) == "string" and ws.tiled_layout ~= "" then
    name = ws.tiled_layout
  else
    local ok2, cfg = pcall(hl.get_config, "general.layout")
    if ok2 and type(cfg) == "string" then
      name = cfg
    end
  end
  if name == "scrolling" or name == "dwindle" then
    return name
  end
  return "other"
end

-- Column width for an item under the current layout (nil for stacked items or
-- when no width is given for this layout).
local function width_for(item)
  local w = item.width
  if type(w) == "table" then
    w = w[state.layout]
  end
  if type(w) ~= "number" then
    return nil
  end
  return w * state.width_scale
end

local function gap_allowance()
  local total = 0
  for _, key in ipairs({ "general.gaps_in", "general.gaps_out" }) do
    local ok, gaps = pcall(hl.get_config, key)
    if ok and type(gaps) == "table" then
      total = total + (tonumber(gaps.left) or 0) + (tonumber(gaps.right) or 0)
    elseif ok and type(gaps) == "number" then
      total = total + 2 * gaps
    end
  end
  return total
end

local function monitor_logical_width(w)
  local m = w.monitor or hl.get_active_monitor()
  if not m then
    return nil
  end
  local width = type(m.size) == "table" and m.size.width or m.width
  local scale = (type(m.scale) == "number" and m.scale > 0) and m.scale or 1
  if type(width) ~= "number" then
    return nil
  end
  return width / scale
end

-- Re-apply a column width that did not stick (focus-free, uses window.resize).
-- Works on both layouts: dwindle adjusts the split ratio of the nearest
-- horizontal split, taking the space from the columns to the right.
local function fix_width(w, item)
  local want = width_for(item)
  if not want then
    return
  end
  local logical = monitor_logical_width(w)
  local actual = type(w.size) == "table" and w.size.x or nil
  if not logical or type(actual) ~= "number" then
    return
  end
  local target = math.floor(want * logical - gap_allowance() + 0.5)
  local delta = target - actual
  if math.abs(delta) > WIDTH_TOLERANCE_PX then
    hl.dispatch(hl.dsp.window.resize({ window = w, x = delta, y = 0, relative = true }))
  end
end

local function focus_window(w)
  pcall(function()
    hl.dispatch(hl.dsp.focus({ window = w }))
  end)
end

local next_step -- forward declaration

local function finish()
  stop_timer("timer")
  stop_timer("settle")
  drop_rule()
  if state.sub then
    pcall(function()
      state.sub:remove()
    end)
    state.sub = nil
  end
  state.pending = nil
  -- Final pass: verify column widths once everything is placed, then report.
  state.settle = hl.timer(function()
    state.settle = nil
    local last_column = state.last_column
    for _, entry in ipairs(state.placed) do
      -- On dwindle the last column is simply the remainder; resizing it would
      -- only steal space back from its neighbour.
      if not (state.layout == "dwindle" and entry.w == last_column) then
        pcall(fix_width, entry.w, entry.item)
      end
    end
    if state.first then
      focus_window(state.first)
    end
    state.running = false
    if state.skipped > 0 then
      notify(string.format("restored %d windows, %d skipped", state.done, state.skipped), "warning", 6000)
    else
      notify(string.format("restored %d windows", state.done), "ok", 2500)
    end
  end, { timeout = SETTLE_MS * 2, type = "oneshot" })
end

local function place(w, item)
  if w.floating then
    hl.dispatch(hl.dsp.window.float({ window = w, action = "disable" }))
  end
  if item.stack and state.layout == "scrolling" then
    -- Scrolling: a new window is its own column; fold it into the one on the left.
    hl.dispatch(hl.dsp.window.move({ window = w, direction = "l" }))
  end
  -- Dwindle: placement was decided before launch (focus + preselect), nothing to move.
  focus_window(w)
  state.first = state.first or w
  state.windows[item] = w
  if not item.stack then
    state.last_column = w
  end
  state.placed[#state.placed + 1] = { w = w, item = item }
  state.done = state.done + 1
  next_step()
end

local function on_open(w)
  local item = state.pending
  if not item or w.class ~= item.class then
    return
  end
  state.pending = nil
  stop_timer("timer")
  drop_rule()
  state.settle = hl.timer(function()
    state.settle = nil
    place(w, item)
  end, { timeout = SETTLE_MS, type = "oneshot" })
end

-- Dwindle: a new window splits the focused window, in the preselected
-- direction. Focus the column head (stack) or the last column (new column) and
-- preselect down/right accordingly. The preselect is consumed by the next
-- window that opens.
local function prepare_dwindle(item)
  local anchor
  if item.stack then
    anchor = item.parent and state.windows[item.parent] or state.last_column
  else
    anchor = state.last_column
  end
  if not anchor then
    return -- first window on the workspace: nothing to split
  end
  focus_window(anchor)
  pcall(function()
    hl.dispatch(hl.dsp.layout(item.stack and "preselect d" or "preselect r"))
  end)
end

next_step = function()
  local item = table.remove(state.queue, 1)
  if not item then
    finish()
    return
  end
  state.pending = item

  -- Temporary rule for this one launch: pin it to the session workspace, keep
  -- it tiled (Omarchy floats some TUIs by default), and set the column width.
  local rule = {
    name = "omarchy-session-" .. item.class,
    match = { class = "^" .. regex_escape(item.class) .. "$" },
    workspace = tostring(state.workspace) .. " silent",
    float = false,
  }
  local want = width_for(item)
  if want and state.layout == "scrolling" then
    rule.scrolling_width = want
  end
  state.rule = hl.window_rule(rule)

  if state.layout == "dwindle" then
    prepare_dwindle(item)
  end

  hl.exec_cmd(item.cmd)
  state.timer = hl.timer(function()
    state.timer = nil
    if state.pending ~= item then
      return
    end
    state.pending = nil
    drop_rule()
    state.skipped = state.skipped + 1
    notify(item.class .. " did not open in time; skipping", "warning", 6000)
    next_step()
  end, { timeout = item.timeout_ms or STEP_TIMEOUT_MS, type = "oneshot" })
end

-- Build the launch queue for the detected layout.
--   scrolling/other: SESSION order as written.
--   dwindle: columns first (left→right), then stacked items, each remembering
--            the column it belongs under; widths scaled to fit the screen.
local function build_queue()
  local queue = {}
  if state.layout ~= "dwindle" then
    for i, item in ipairs(SESSION) do
      queue[i] = item
    end
    return queue
  end

  local stacks, parent, total = {}, nil, 0
  for _, item in ipairs(SESSION) do
    if item.stack then
      stacks[#stacks + 1] = { item = item, parent = parent }
    else
      queue[#queue + 1] = item
      parent = item
      local w = item.width
      if type(w) == "table" then
        w = w.dwindle
      end
      total = total + (tonumber(w) or 0)
    end
  end
  state.width_scale = (total > 1) and (1 / total) or 1
  for _, s in ipairs(stacks) do
    -- Shallow copy so SESSION itself stays untouched between runs.
    local copy = {}
    for k, v in pairs(s.item) do
      copy[k] = v
    end
    copy.parent = s.parent
    queue[#queue + 1] = copy
  end
  return queue
end

local function start(workspace)
  workspace = workspace or WORKSPACE
  if state.running then
    notify("already running", "warning")
    return false
  end
  local ok, existing = pcall(hl.get_workspace_windows, workspace)
  if ok and type(existing) == "table" and #existing > 0 then
    notify("workspace " .. tostring(workspace) .. " is not empty; not restoring", "warning", 6000)
    return false
  end
  state = fresh_state()
  state.running = true
  state.workspace = workspace
  state.layout = detect_layout(workspace)
  state.queue = build_queue()
  hl.dispatch(hl.dsp.focus({ workspace = tostring(workspace) }))
  state.sub = hl.on("window.open", on_open)
  next_step()
  return true
end

-- Global handle so it can be triggered from `hyprctl eval` or a keybind.
omarchy_session = { restore = start }

hl.on("hyprland.start", function()
  state.boot = hl.timer(function()
    start(WORKSPACE)
  end, { timeout = START_DELAY_MS, type = "oneshot" })
end)
