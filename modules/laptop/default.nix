{ lib, self, ... }:
with lib;
{
  imports = [
    self.nixosModules.gui-common
    self.nixosModules.unbound
  ];

  lmh01 = {
    unbound.enable = true;
    options.type = "laptop";
  };
}
