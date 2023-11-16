{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.bluetooth;
in
{

  options.lmh01.bluetooth = {
    enable = mkEnableOption "activate bluetooth";
  };

  config = mkIf cfg.enable {

    hardware.bluetooth.enable = true;
    services.blueman.enable = true;

  };
}