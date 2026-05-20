## Generate SSH keys on new system to clone files from github. 
```sh
ssh-keygen -t ed25519 -C "abcdef@gmail.com"
cat ~/.ssh/id_ed25519.pub
```
Add the key to git repo.

## Install nix on non nixos systems e.g. for macos:
```sh
#The below will install nix from upstream and not determinate
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
```

## Clone the git repository; using nix shell instead of run as we need git for the session
```sh
nix shell --extra-experimental-features nix-command --extra-experimental-features flakes nixpkgs#git
git clone git@github.com:nazmir/nix-config.git
```

## Link the newly renamed configuration files to the nix-config directory
The script will backup the files in source directory (arg1) and link to target directory.  
Don't rename hardware config to specific machine as configuration.nix

```sh
sudo ~/dev/nix-config/bin/rename-and-link.sh /etc/nixos/configuration.nix ~/dev/nix-config/nixos/hosts/pc/configuration-pc.nix
sudo ~/dev/nix-config/bin/rename-and-link.sh /etc/nixos/hardware-configuration.nix ~/dev/nix-config/nixos/hosts/pc/hardware-configuration.nix
sudo nixos-rebuild switch --flake $HOME/dev/nix-config/.#mir-nixos-pc
```

## Install Home manager as a standalone using flakes for nixos and non nixos systems
Before installing home manager run nix flake update and then link the config file to git repo

``` nix
cd ~/dev/nix-config
nix flake update

#For non nixos systems like macOS. The below will install nix from upstream and not determinate.
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

#this will initialize home manager and place config file in ~/.config/home-manager/home.nix 
nix run home-manager/master -- init --switch

rm ~/.config/home-manager/flake.*
~/dev/nix-config/bin/rename-and-link.sh ~/.config/home-manager/home.nix ~/dev/nix-config/home-manager/hosts/home-nixos.nix  
  
#initial evaluation with flakes  
home-manager switch --flake ~/dev/nix-config/.#mir@mir-nixos-pc

#configure prompt for fish with tide as fish is installed now via home-manager
tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time='24-hour format' --rainbow_prompt_separators=Vertical --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='One line' --prompt_spacing=Sparse --icons='Many icons' --transient=No

#macos specific functionality
sudo sh -c 'echo $HOME/.nix-profile/bin/fish >> /etc/shells'
chsh -s $HOME/.nix-profile/bin/fish 
```

## To update the system
```nix 
nix flake update
```

## Using *`nh`* helper to rebuild system or home manager

``` nix
nh os switch --ask #Ask for confirmation before applying configuration
nh home switch --ask
#home-manager switch --flake '.#mir@mir-nixos-pc'
nh home switch -c mir@mir-nixos-pc ./

#To specify flakes explicitly use:
nh os switch --ask ~/dev/nix-config/.#mir-nixos-thinkpad

#To use the current hostname and specify flake path reference use:
nh os switch --ask ~/dev/nix-config/ 
```

## Garbage collection using *`nh`* helper

``` nix
nh clean all #Clean OS and Home profiles
nh clean user #clean user profiles
```

## Cleaning specific profiles 

``` nix
nix profile list
nh clean profile -a nixGL #nixGL is profile name and -a asks for confirmation
```

## Apply config via flakes in case *`nh`* helper is not installed
```nix
sudo nixos-rebuild switch --flake $HOME/dev/nix-config/.#mir-nixos-thinkpad
home-manager switch --flake $HOME/dev/nix-config/.#mir@mir-nixos-thinkpad
```

## Activating tailscale
```sh
 sudo tailscale up -authkey tskey-auth-KEY #Get key from tailscale console
```
 
## Nixos check build difference if *`nh`* helper is not installed
Build the result before switching  
```sh 
sudo nixos-rebuild build --flake $HOME/dev/nix-config/.#mir-nixos-thinkpad 
``` 

To compare current system with build result run  
```nix 
nvd diff /run/current-system/ ./result/ 
nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2) #To compare result after switch
```

nvd uses nix store diff-closure, but with improved reporting. Syntax for nix store diff-closure is:  
```nix 
nix store diff-closures $(ls -d1v /nix/var/nix/profiles/system-*-link|tail -n 2)
```

# Other Package configuration

## Doom Emacs configuration
Install Doom Emacs and make sure to run  
`doom doctor` #To check for any issues

Backup ~/.emacs.d if it exists  

``` sh
mv ~/.emacs.d ~/.emacs.d.orig
```

Copy doom configuration files to ~/.nix-config/.config/doom  

```sh
~/dev/nix-config/bin/rename-and-link.sh ~/.config/doom/ ~/dev/nix-config/.config/doom
```

## sway config
```sh
~/dev/nix-config/bin/rename-and-link ~/.config/sway/config ~/.config/sway/config
```
## Kitty configuration

```sh
~/dev/nix-config/bin/rename-and-link ~/.config/kitty/ ~/dev/nix-config/.config/kitty 
#The result will be in current folder
```

