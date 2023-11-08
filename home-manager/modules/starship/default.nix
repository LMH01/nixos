{ lib, config, ... }:
with lib;
let cfg = config.lmh01.programs.starship;
in
{

  options.lmh01.programs.starship.enable = mkEnableOption "activate starship";

  config = mkIf cfg.enable {

    programs.starship = {
      enable = true;
      settings = {
        sudo = {
          style = "bold green";
          symbol = "🌟 ";
          disabled = false;
        };
      };
    };

  };
}
