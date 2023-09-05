# NixOS

This repository reflects my try at learning NixOS, it contains my current configurations.

## Usage

To update your NixOS system to one of my configurations, you can use the following command:
```
nixos-rebuild switch --flake '.#<configuration_name>'
```
Note that you have to update the corresponding hardware configuration to fit your system before you can run the command. You might also want to change the username beforehand.

Rust modul in home manager verschieben und rust-analyzer vscode extension nur installieren, wenn rust modul an ist. (siehe latex modul, schauen, ob das problem mit der nicht deaktivierten extension da auch dann der Fall ist)
