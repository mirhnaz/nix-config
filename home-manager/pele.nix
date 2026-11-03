{ pkgs, ... }:
let
  version = "1.13.0";
  source = pkgs.fetchurl {
    url = "https://registry.npmjs.org/pele/-/pele-${version}.tgz";
    hash = "sha512-Ie8UKY9x00MsuR3jO6AzUwzK2Z6MIV3Tf4EDdITiuk8Uaz8K7g0R082WqsqNaSU8DdgkrRvZThzhit83mi/uiw==";
  };
  # Pele has no runtime dependencies. Use its published bundle without npm
  # activation hooks or a second Node installation in the Nix closure.
  pele = pkgs.runCommand "pele-render-${version}" { } ''
    mkdir -p "$out/bin" "$out/lib/node_modules/pele"
    tar -xzf ${source} --strip-components=1 -C "$out/lib/node_modules/pele"
    cp ${./pele-render.mjs} "$out/lib/pele-render.mjs"
    cat > "$out/bin/pele-render" <<EOF
    #!${pkgs.runtimeShell}
    # Node comes from Homebrew on macOS and mise on Omarchy.
    exec /usr/bin/env node "$out/lib/pele-render.mjs" "\$@"
    EOF
    chmod +x "$out/bin/pele-render"
  '';
in
{
  home.packages = [ pele ];
}
