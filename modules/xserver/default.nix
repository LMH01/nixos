{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.xserver;
in
{

  options.lmh01.xserver.enable = mkEnableOption "activate xserver";
  

  config = mkIf cfg.enable {

    # Enable the X11 windowing system.
    services.xserver = {
      layout = "de";
      enable = true;
      autorun = true;
      libinput = {
        enable = true;
        touchpad.accelProfile = "flat";
      };

      desktopManager = {
        xterm.enable = false;
        session = [{
          name = "home-manager";
          start = ''
            export `dbus-launch`
            ${pkgs.runtimeShell} $HOME/.hm-xsession &
             waitPID=$!
          '';
        }];
      };

    };

  };
}