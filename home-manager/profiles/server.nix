# Server only stuff
{ lib, pkgs, flake-self, config, system-config, ... }:
with lib;
{

  config = {

    home.packages = with pkgs; [
      flake-self.inputs.simple-update-checker
      tmux
    ] ++ lib.optionals (system-config.nixpkgs.hostPlatform.system == "x86_64-linux") [ ];

    programs = { };

    services = { };

  };

}
