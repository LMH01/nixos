# Hermes Agent (Nous Research) running in an OCI container.
# The hermes CLI on the host routes every command into the container.
{ lib, hermes-agent, config, ... }:
with lib;
let cfg = config.lmh01.hermes;
in
{
  imports = [ hermes-agent.nixosModules.default ];

  options.lmh01.hermes = {
    enable = mkEnableOption "activate the Hermes Agent (Nous Research) in an OCI container";
  };

  config = mkIf cfg.enable {
    services.hermes-agent = {
      enable = true;
      addToSystemPackages = true;

      # run the agent (and the commands it runs) inside a container;
      # docker is enabled via modules/common on all hosts
      container = {
        enable = true;
        backend = "docker";
        hostUsers = [ "louis" ];
      };
    };
  };
}
