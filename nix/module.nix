{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.gerrit-autosubmit;
  description = "gerrit-autosubmit - autosubmit bot for Gerrit";
  mkStringOption =
    default:
    lib.mkOption {
      inherit default;
      type = lib.types.str;
    };
in
{
  options.services.gerrit-autosubmit = {
    enable = lib.mkEnableOption description;

    gerritUrl = mkStringOption "https://gerrit.example.com";

    gerritUsername = mkStringOption "autosubmit-bot";

    pollInterval = lib.mkOption {
      description = "Poll interval in seconds between autosubmit attempts";
      default = 30;
      type = lib.types.int;
    };

    secretsFile = lib.mkOption {
      description = "Path to a systemd EnvironmentFile containing secrets";
      default = config.age.secretsDir + "/gerrit-autosubmit";
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.gerrit-autosubmit = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = lib.getExe pkgs.gerrit-autosubmit;
        DynamicUser = true;
        Restart = "always";
        EnvironmentFile = cfg.secretsFile;
      };

      environment = {
        GERRIT_URL = cfg.gerritUrl;
        GERRIT_USERNAME = cfg.gerritUsername;
        GERRIT_POLL_INTERVAL_SECS = toString cfg.pollInterval;
      };
    };
  };
}
