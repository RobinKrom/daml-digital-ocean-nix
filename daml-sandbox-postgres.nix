{
  network = {
        enableRollback = true;
        network.description = "One machine hosting a daml sandbox backed by a postgres database.";
      };

  resources.sshKeyPairs.ssh-key = {};

  machine = { config, pkgs, lib, ... }:
  let projectConfig = import ./project-config.nix;
  in
  {
    imports = [./daml-sandbox.nix];
    environment.systemPackages = [ (import ./daml-sdk.nix {inherit pkgs;})];
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    # ssh
    services.openssh.enable = true;

    # daml user
    users.users.daml = {
      isSystemUser = true;
      description = "The DAML system user";
      extraGroups = [ "wheel" ];
    };

    # postgresql
    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql_12;
    services.postgresql.ensureDatabases = [ "${config.services.daml-sandbox.ledgerid}" ];
    services.postgresql.ensureUsers = [
      { name = "daml";
        ensurePermissions = {
          "DATABASE ${config.services.daml-sandbox.ledgerid}" = "ALL PRIVILEGES";
        };
      }
    ];
    # we set the authentication from localhost to trust, because jdbc doesn't connect via unix
    # sockets.
    services.postgresql.authentication = lib.mkForce ''
      # Generated file; do not edit!
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     ident
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 md5
    '';

    # daml-sandbox
    services.daml-sandbox.enable = true;
    services.daml-sandbox.ledgerid = projectConfig.ledgerId;
    services.daml-sandbox.auth-cert = ./auth0.cert;
    services.daml-sandbox.port = 7575;

    # nginx
    services.nginx = {
      enable = true;
      virtualHosts.${projectConfig.hostName} = {
        enableACME = true;
        forceSSL = true;
        preStart = ''
          mkdir -p /var/www
        '';
        root = "/var/www/${config.services.daml-sandbox.ledgerid}/";
        locations."/v1" = {
          extraConfig = ''proxy_pass http://localhost:7575;'';
        };
        # forward other requests to index.html and let the react router handle them.
        locations."/" = {
         extraConfig = ''try_files $uri /index.html; '';
        };
      };
    };
    security.acme.email = projectConfig.email;
    security.acme.acceptTerms = true;

    # deployment on digital ocean
    deployment.targetEnv = "digitalOcean";
    deployment.digitalOcean.enableIpv6 = true;
    deployment.digitalOcean.region = projectConfig.serverRegion;
    deployment.digitalOcean.size = projectConfig.serverSize;
  };
}
