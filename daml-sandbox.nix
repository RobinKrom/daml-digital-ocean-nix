{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.daml-sandbox;
  daml-sdk = import ./daml-sdk.nix {inherit pkgs;};
  projectConfig = import ./project-config.nix;
in

{
  options = {
    services.daml-sandbox = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to run the DAML sandbox ledger.
        '';
      };

      ledgerid = mkOption {
        type = types.lines;
        default = "NO_LEDGER_ID";
        description = ''
          The ledger identification.
        '';
      };

      auth-cert = mkOption {
        type = types.path;
        description = ''
          Path to the certificate used to sign the jwt-rs256 authentication token.
        '';
      };

      dar = mkOption {
        type = types.path;
        description = ''
          The dar package for the sandbox to load.
        '';
      };

      port = mkOption {
        type = types.port;
        description = ''
          The port where the DAML JSON API will be served.
        '';
      };

    };
  };

  config = mkIf config.services.daml-sandbox.enable {
    environment.systemPackages = [ daml-sdk ];

    systemd.services.daml-sandbox=
      { description = "DAML sandbox";

        wantedBy = [ "multi-user.target" ];
        wants = [" postgres.service" ];
        after = [ "network.target" "postgres.service"];

        path = [ daml-sdk ];
        script =
          ''
             TOKEN=`mktemp`
             echo -n "Bearer " >> $TOKEN
             ${pkgs.curl}/bin/curl \
                  --request POST \
                  --url https://dev-8xkawbyi.auth0.com/oauth/token \
                  --header 'content-type: application/json' \
                  --data '{"client_id":"${projectConfig.auth0.clientId}", "client_secret":"${projectConfig.auth0.clientSecret}", "audience":"localhost/sandbox", "grant_type":"client_credentials"}' \
             | ${pkgs.jq}/bin/jq -r .access_token >> $TOKEN

             daml sandbox --ledgerid=${cfg.ledgerid} \
                --auth-jwt-rs256-crt=${cfg.auth-cert} \
                --port 6865 \
                --sql-backend-jdbcurl "jdbc:postgresql:${cfg.ledgerid}" \
                --wall-clock-time &

             sleep 10
             exec daml json-api --http-port=${toString cfg.port} \
                                --ledger-host=localhost \
                                --ledger-port=6865 \
                                --access-token-file=$TOKEN \
                                --application-id=${cfg.ledgerid}
          '';

        serviceConfig =
          { ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
            User = "daml";
            # Group = "daml";
            PermissionsStartOnly = true;

            # Shut down sandbox using SIGINT
            KillSignal = "SIGINT";
            KillMode = "mixed";

            # Give the sandbox a decent amount of time to clean up after
            # receiving systemd's SIGINT.
            TimeoutSec = 30;
          };

        # Wait for the sandbox/navigator to be ready to accept connections.
      };
  };
}
