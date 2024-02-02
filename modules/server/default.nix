# this file contains the modules that
# should be enabled on all my servers
{ lib, self, ... }:
with lib;
{
  imports = [
    self.nixosModules.common
  ];

  lmh01 = {
    options.type = "server";
  };
}
