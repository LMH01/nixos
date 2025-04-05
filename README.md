# NixOS

This repository reflects my try at learning NixOS, it contains my current configurations.

This repository uses [sops-nix](https://github.com/Mic92/sops-nix), so don't be alarmed to see the file [secrets/secrets.yaml](secrets/secrets.yaml). This file is included in this repository by design.

## Usage

To update your NixOS system to one of my configurations, you can use the following command:
```
nixos-rebuild switch --flake '.#<configuration_name>'
```
Note that you have to update the corresponding hardware configuration to fit your system before you can run the command. You might also want to change the username beforehand.

## Type modules

I am using 5 modules that specify common modules that should be used on all systems of that specific type:

| Name | Description | Inherited Module |
| - | - | - |
| [common](modules/common/default.nix) | all my systems | |
| [gui-common](modules/gui-common/default.nix) | only systems with gui | common |
| [laptop](modules/laptop/default.nix) | laptop systems | gui-common |
| [desktop](modules/desktop/default.nix) | desktop systems | gui-common |
| [server](modules/server/default.nix) | server systems | common |

Above modules definitions are also used in home manager.