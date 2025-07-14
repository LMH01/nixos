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
    self.nixosModules.services
    #self.nixosModules.tailscale
    self.nixosModules.users
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = [ "/home/louis/.ssh/id_ed25519" ];
    secrets = { };
    templates = { };
  };

  lmh01 = {
    services = {
      syncthing.enable = true;
    };
    docker.enable = true;
    openssh.enable = true;
    users = {
      louis.enable = true;
      root.enable = true;
    };
    # disabled for now as it is no longer needed
    #tailscale.enable = true;
  };

  # enable vscode server on all system
  programs.nix-ld.enable = true;
}
