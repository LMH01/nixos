{ lib, ... }: with lib;
{
  options.lmh01 = {
    secrets = mkOption {
      type = types.str;
      default = "/home/louis/.secrets";
      description = "storage path for all secrets";
    };
    storage = mkOption {
      type = types.str;
      default = "/var/lib/storage";
      description = "storage path for all service data";
    };
  };
}
