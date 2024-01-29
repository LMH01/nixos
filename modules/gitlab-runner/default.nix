{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.gitlab-runner;
in {
  options.lmh01.gitlab-runner.enable = mkEnableOption "activate gitlab-runner(s)";
  config = mkIf cfg.enable {
    services.gitlab-runner = {
      enable = true;

      # main gitlab-cs runner for rust
      services.gitlab-cs-runner-rust = {
        dockerImage = "rust:latest";
        # this registration file needs to be configured for each host individually
        registrationConfigFile = "/home/louis/.gitlab-runner/gitlab-cs-runner-rust";
      };

      # the config file looks like this:
      # CI_SERVER_URL={YOUR_URL}
      # REGISTRATION_TOKEN={YOUR_TOKEN}
      # DOCKER_SECURITY_OPT=seccomp:unconfined # required for cargo tarpaulin
      # DOCKER_SERVICES_SECURITY_OPT=seccomp:unconfined #required for cargo tarpaulin

    };
  };
}
