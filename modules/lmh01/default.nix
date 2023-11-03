{ lib, ... }: with lib;
{
  options.lmh01 = {
    secrets = mkOption {
      type = types.str;
      default = "/home/louis/.secrets";
      description = "storage path for all secrets";
    };
  };
}
