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
      nvidia = {
      	open = true;
      	modesetting.enable = true;
      	powerManagement.enable = true;
	      nvidiaSettings = true;
      };
    };

    # when docker is enabled, enable nvidia-docker
    virtualisation.docker.enableNvidia = lib.mkIf config.virtualisation.docker.enable true;

    environment.systemPackages = with pkgs; [ 
      nvtop 
    ];

    # fix electron problems with nvidia
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

  };
}
