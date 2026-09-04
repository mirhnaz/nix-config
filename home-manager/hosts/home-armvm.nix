{config, pkgs, ... }:

{
  imports = [
      ../common.nix
      ../common-linux.nix
  ];
  
  home.packages = with pkgs; [
    gparted
    kitty

  ];

  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = with builtins;
        let extension = shortId: uuid: {
          name = uuid;
          value = {
            install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
            installation_mode = "normal_installed";
          };
        };
        in listToAttrs [
          (extension "ublock-origin" "uBlock0@raymondhill.net")
          (extension "1password-x-password-manager" "{d634138d-c276-4fc8-924b-40a0ea21d284}")
        ];
        # To add additional extensions, find it on addons.mozilla.org, find
        # the short ID in the url (like https://addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
        # Then, download the XPI by filling it in to the install_url template, unzip it,
        # run `jq .browser_specific_settings.gecko.id manifest.json` or
        # `jq .applications.gecko.id manifest.json` to get the UUID
    };
    profiles = {
      profile_0 = {           # choose a profile name; directory is /home/<user>/.mozilla/firefox/profile_0
        id = 0;               # 0 is the default profile; see also option "isDefault"
        name = "profile_0";   # name as listed in about:profiles
        isDefault = true;     # can be omitted; true if profile ID is 0
        settings = {          # specify profile-specific preferences here; check about:config for options
          "browser.newtabpage.activity-stream.feeds.section.highlights" = false;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
        };
      };
    };
  };

  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";
		font = {
			size = 10;
			name = "Noto Sans";
    };

		#extraConfig = "
		#	background_opacity 1
		#	background_blur 0
    # remember_window_size yes
    # tab_bar_min_tabs 1
		#	tab_bar_edge bottom
    # tab_bar_style custom
		#	tab_powerline_style slanted
		#	tab_title_template \" {'󰊠 ' if (index % 2) == 0 else '󰆘 '}{fmt.bold}{sup.index}\"
		#	active_tab_title_template \" 󰮯 {fmt.nobold}{sup.index}\"
    #";
  };
}
