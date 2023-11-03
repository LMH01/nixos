{ lib, ... }: with lib;
{
  options.lmh01 = {
    secrets = mkOption {
      type = types.str;
      default = "/home/louis/.pwd";
      description = "storage path for all secrets";
    };
  };
}
