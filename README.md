# NixOS

This repository reflects my try at learning NixOS, it contains my current configurations.

## Usage

To update your NixOS system to one of my configurations, you can use the following command:
```
nixos-rebuild switch --flake '.#<configuration_name>'
```
Note that you have to update the corresponding hardware configuration to fit your system before you run the command. You might also want to change the username beforehand.
