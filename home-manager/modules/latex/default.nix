{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.programs.latex;
in {

  options.lmh01.programs.latex.enable = mkEnableOption "enable latex using texlive";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      texlive.combined.scheme-full
    ];

    # enable vscode extension
    programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [ james-yu.latex-workshop ];
  };

}
