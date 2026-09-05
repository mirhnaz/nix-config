{
  config,
  pkgs,
  inputs,
  ...
}:

{

  imports = [
    ./common.nix
  ];

  home.packages = with pkgs; [

    #sytem utils
    nvd
    nix-du
    killall
    ethtool

    #lang utils
    nixd
    nil
    vscode
    emacs-all-the-icons-fonts
    devin-desktop # was `windsurf`; nixpkgs renamed the package after the rebrand

    #system utils
    alacritty
  ];

}
