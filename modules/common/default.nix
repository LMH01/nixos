# this file contains the modules that
# should be enabled on all my systems
{ lib, self, ... }:
with lib;
{
  imports = [
    self.nixosModules.docker
    self.nixosModules.lmh01
    self.nixosModules.locale
    self.nixosModules.nix-common
    self.nixosModules.openssh
    self.nixosModules.syncthing
    self.nixosModules.tailscale
    self.nixosModules.users
  ];

  lmh01 = {
    docker.enable = true;
    openssh.enable = true;
    syncthing.enable = true;
    users = {
      louis.enable = true;
      root.enable = true;
    };
    tailscale.enable = true;
  };
}
