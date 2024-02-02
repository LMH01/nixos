# this filecontains the modules that
# should be enabled on all my systems with gui
{ lib, pkgs, config, self, ... }:
with lib;
let cfg = config.lmh01.gui-common;
in
{
  imports = [
    self.nixosModules.common
    self.nixosModules.libreoffice
    self.nixosModules.syncthing
    self.nixosModules.wg-sn
    self.nixosModules.wireguard
    self.nixosModules.xserver
    self.nixosModules.virtualisation
  ];

  lmh01 = {
    libreoffice.enable = true;
    syncthing.enable = true;
    wg-sn.enable = true;
    wireguard.enable = true;
    xserver.enable = true;
    virtualisation.enable = true;
  };
  
  programs.thunar.enable = true;
  programs.xfconf.enable = true; # required to make thunar settings persistant
}
