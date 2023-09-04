{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.nvidia;
in
{

  options.lmh01.nvidia = {
    enable = mkEnableOption "activate nvidia support";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    # Nvidia settings
    hardware = {
      opengl = {
        enable = true;
        driSupport = true;
        driSupport32Bit = true;
      };
      nvidia.modesetting.enable = true;
      nvidia.powerManagement.enable = true;
    };

    # when docker is enabled, enable nvidia-docker
    virtualisation.docker.enableNvidia = lib.mkIf config.virtualisation.docker.enable true;

    environment.systemPackages = with pkgs; [ nvtop ];

  };
}
