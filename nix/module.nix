{ config, lib, pkgs, ... }:

let
  cfg = config.services.gerrit-autosubmit;
  inherit (lib) types mkOption mkIf mkEnableOption literalExpression;
in
{
  options.services.gerrit-autosubmit = {
    enable = mkEnableOption "Gerrit autosubmit bot";

    package = mkOption {
      type = types.package;
      default = pkgs.gerrit-autosubmit;
      defaultText = literalExpression "pkgs.gerrit-autosubmit";
      description = "gerrit-autosubmit package to use";
    };

    gerritUrl = mkOption {
      type = types.str;
      default = "https://cl.snix.dev";
      description = "Gerrit instance base URL";
    };

    gerritUsername = mkOption {
      type = types.str;
      default = "clbot";
      description = "Gerrit username";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/gerrit-autosubmit";
      description = ''
        Path to a systemd EnvironmentFile containing GERRIT_PASSWORD.
        See systemd.exec(5) for the format.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.gerrit-autosubmit = {
      description = "gerrit-autosubmit - autosubmit bot for Gerrit";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/gerrit-autosubmit";
        DynamicUser = true;
        Restart = "always";
        RestartSec = "30s";
      } // lib.optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };

      environment = {
        GERRIT_URL = cfg.gerritUrl;
        GERRIT_USERNAME = cfg.gerritUsername;
      };
    };
  };
}
