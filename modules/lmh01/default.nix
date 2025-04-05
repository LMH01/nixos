{ lib, ... }: with lib;
{
  options.lmh01 = {
    storage = mkOption {
      type = types.str;
      default = "/var/lib/storage";
      description = "storage path for all service data";
    };
  };
}
