{ lib, pkgs, config, ... }: {

  services.xserver.videoDrivers = [ "nvidia" ];

  # Nvidia settings
  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };
    nvidia.modesetting.enable = true;
    powerManagement.enable = true;
  };

  # when docker is enabled, enable nvidia-docker
  virtualisation.docker.enableNvidia = lib.mkIf config.virtualisation.docker.enable true;

  environment.systemPackages = with pkgs; [ nvtop ];

}
