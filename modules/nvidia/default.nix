{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.lmh01.nvidia;

  # packages that should be built with CUDA support on NVIDIA systems
  cudaoverlay = (self: super: {
    inherit (pkgs.cudapkgs)
      handbrake
      ;
  });

in
{

  options.lmh01.nvidia = {
    enable = mkEnableOption "activate nvidia support";
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    nixpkgs = { overlays = [ cudaoverlay ]; };

    # TODO:
    # only should be set when louis is a home-manager user
    home-manager.users = {
      louis = {
        nixpkgs = { overlays = [ cudaoverlay ]; };
      };
    };

    # Nvidia settings
    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      nvidia = {
        open = false; # with the open driver the screen will keep black after waking the pc from suspend
        modesetting.enable = true;
        powerManagement.enable = true;
        nvidiaSettings = true;
      };
    };

    # when docker is enabled, enable nvidia-docker
    virtualisation.docker.enableNvidia = lib.mkIf config.virtualisation.docker.enable true;

    environment.systemPackages = with pkgs; [
      nvtopPackages.full
    ];

    # fix electron problems with nvidia
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

  };
}
