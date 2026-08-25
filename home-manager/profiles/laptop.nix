# Laptop only stuff
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  config = {

    home.packages = with pkgs; [
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    programs = { };

    services = {
      # TODO move into i3/sway config and enable there only if on laptop
      blueman-applet.enable = true; # bluetooth tray
     };

  };

}
