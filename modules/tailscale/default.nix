{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.tailscale;
in {
  options.lmh01.tailscale.enable = mkEnableOption "activate tailscale service";
  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };
}
