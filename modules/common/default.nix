# This file will contain stuff that I use on all my systems
{ lib, self, ... }:
with lib;
{
  imports = [
    self.nixosModules.lmh01
  ];
}
