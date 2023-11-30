{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.libreoffice;
in {
  options.lmh01.libreoffice.enable = mkEnableOption "activate libreoffice";
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libreoffice-qt
      hunspell
      hunspellDicts.en_US
      hunspellDicts.de_DE
    ];
  };
}
