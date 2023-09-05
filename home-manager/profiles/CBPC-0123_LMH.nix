# This file contains stuff that should only be setup on my main desktop pc
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  config = {

    home.packages = with pkgs; [
      hashcat
      steam
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    programs = {
      
    };

    services = {

    };

  };

}
