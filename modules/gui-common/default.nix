# this filecontains the modules that
# should be enabled on all my systems with gui
{ lib, pkgs, config, self, vscode-server, ... }:
with lib;
let cfg = config.lmh01.gui-common;
in
{
  imports = [
    self.nixosModules.common
    self.nixosModules.libreoffice
    self.nixosModules.qmk
    #self.nixosModules.wg-sn
    self.nixosModules.wireguard
    self.nixosModules.xserver
    self.nixosModules.virtualisation
    vscode-server.nixosModules.default
  ];

  lmh01 = {
    libreoffice.enable = true;
    qmk.enable = true;
    #wg-sn.enable = true; # disabled until it is needed again
    wireguard.enable = true;
    xserver.enable = true;
    virtualisation.enable = true;
  };
  
  programs.thunar.enable = true;
  programs.xfconf.enable = true; # required to make thunar settings persistant

  # service needs to be enabled manually for each user:
  # systemctl --user enable auto-fix-vscode-server.service
  services.vscode-server.enable = true;
}
