{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.qmk;
in {
  options.lmh01.qmk.enable = mkEnableOption "activate qmk containers";
  config = mkIf cfg.enable {
    services.udev.packages = with pkgs; [
      vial
      via
    ];
    environment.systemPackages = with pkgs; [
      via
      qmk
    ];
  };
}