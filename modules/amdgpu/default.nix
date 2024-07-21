{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.amdgpu;
in
{

  options.lmh01.amdgpu = {
    enable = mkEnableOption "activate amdgpu support";
  };

  config = mkIf cfg.enable {

    # make kernel load module early
    #boot.initrd.kernelModules = [ "amdgpu" ]; #disabled because it impacts boot time

    services.xserver.videoDrivers = [ "amdgpu" ];

    hardware.opengl.extraPackages = with pkgs; [
      rocm-opencl-icd
      rocm-opencl-runtime
      amdvlk 
    ];

    # vulkan
    hardware.graphics.driSupport = true;
    # For 32 bit applications
    hardware.graphics.enable32Bit = true;

    # For 32 bit applications 
    # Only available on unstable
    hardware.opengl.extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];
  };
}
