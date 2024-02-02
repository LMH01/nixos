{ lib, self, ... }:
with lib;
{
  imports = [
    self.nixosModules.gitlab-runner
    self.nixosModules.gui-common
    self.nixosModules.steam
  ];

  lmh01 = {
    gitlab-runner.enable = true;
    steam.enable = true;
    options.type = "desktop";
  };
}
