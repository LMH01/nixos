{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.wayland;
in
{

  options.lmh01.wayland.enable = mkEnableOption "activate wayland";

  config = mkIf cfg.enable {

    security = {
      polkit.enable = true;
      rtkit.enable = true;
    };

    hardware = {
      # fixes'ÈGL_EXT_platform_base not supported'
      graphics.enable = true;
      # nvidia-drm.modeset=1 is required for some wayland compositors, e.g. sway
      nvidia.modesetting.enable = mkIf config.lmh01.nvidia.enable true;
    };

  };
}
