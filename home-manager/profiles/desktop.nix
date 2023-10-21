# This file contains stuff that should only be setup on my desktop pc's
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  config = {

    home.packages = with pkgs; [
      hashcat
      prismlauncher # minecraft launcher
      steam
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    programs = { };

    services = { };

  };

}
