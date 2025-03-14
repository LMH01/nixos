{ pkgs, lib, config, ... }:
with lib;
let cfg = config.lmh01.programs.direnv;
in
{

  options.lmh01.programs.direnv = {
    enable = mkEnableOption "activate direnv";
  };

  config = mkIf cfg.enable {

    programs = {
      direnv = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
      git = { ignores = [ ".direnv/" ]; };
      vscode = { profiles.default.extensions = with pkgs.vscode-extensions; [ mkhl.direnv ]; };
    };

  };

}