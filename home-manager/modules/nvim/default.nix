{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.programs.nvim;
in
{

  options.lmh01.programs.nvim.enable = mkEnableOption "activate neovim";

  config = mkIf cfg.enable {

    programs.neovim = {
      enable = true;
      defaultEditor = true;
    };

  };
}
