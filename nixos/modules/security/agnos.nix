{ config, lib, pkgs, ... }:
let
  cfg = config.security.agnos;
  format = pkgs.formats.toml { };
  name = "agnos";
  stateDir = "/var/lib/${name}";

  accountType = with lib; types.submodule {
    freeformType = format.type;

    options = {
      email = mkOption {
        type = types.str;
        description = ''
          Email associated with this account.
        '';
      };
      private_key_path = mkOption {
        type = types.str;
        description = ''
          Path of the PEM-encoded private key for this account.
          Currently, only RSA keys are supported.

          If this path does not exist, then the behavior depends on `generateKeys.enable`.
          When this option is `true`,
          the key will be automatically generated and saved to this path.
          When it is `false`, agnos will fail.

          If a relative path is specified,
          the key will be looked up (or generated and saved to) under `${stateDir}`.
        '';
      };
      certificates = mkOption {
        type = types.listOf certificateType;
        description = ''
          Certificates for agnos to issue or renew.
        '';
      };
    };
  };

  certificateType = with lib; types.submodule {
    freeformType = format.type;

    options = {
      domains = mkOption {
        type = types.listOf types.str;
        description = ''
          Domains the certificate represents
        '';
        example = literalExpression ''["a.example.com", "b.example.com", "*b.example.com"]'';
      };
      fullchain_output_file = mkOption {
        type = types.str;
        description = ''
          Output path for the full chain including the acquired certificate.
          If a relative path is specified, the file will be created in `${stateDir}`.
        '';
      };
      key_output_file = mkOption {
        type = types.str;
        description = ''
          Output path for the certificate private key.
          If a relative path is specified, the file will be created in `${stateDir}`.
        '';
      };
    };
  };
in
{
  options.security.agnos = with lib; {
    enable = mkEnableOption name;

    settings = mkOption {
      description = "Settings";
      type = types.submodule {
        freeformType = format.type;

        options = {
          dns_listen_addr = mkOption {
            type = types.str;
            default = "0.0.0.0:53";
            description = ''
              Address for agnos to listen on.
              Note that this needs to be reachable by the outside world,
              and 53 is required in most situations
              since `NS` records do not allow specifying the port.
            '';
          };

          accounts = mkOption {
            type = types.listOf accountType;
            description = ''
              A list of ACME accounts.
              Each account is associated with an email address
              and can be used to obtain an arbitrary amount of certificate
              (subject to provider's rate limits,
              see e.g. [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)).
            '';
          };
        };
      };
    };

    generateKeys = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable automatic generation of account keys.

          When this is `true`, a key will be generated for each account where
          the file referred to by the `private_key` path does not exist yet.

          Currently, only RSA keys can be generated.
        '';
      };

      keySize = mkOption {
        type = types.int;
        default = 4096;
        description = ''
          Key size in bits to use when generating new keys.
        '';
      };
    };

    server = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        ACME Directory Resource URI. Defaults to Let's Encrypt's production endpoint,
        `https://acme-v02.api.letsencrypt.org/directory`, if unset.
      '';
    };

    serverCa = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        The root certificate (in PEM format) of the ACME server's HTTPS interface.
      '';
    };

    persistent = mkOption {
      type = types.bool;
      default = true;
      description = ''
        When `true`, use a persistent systemd timer.
      '';
    };

    startAt = mkOption {
      type = types.either types.str (types.listOf types.str);
      default = "weekly";
      example = "02:00";
      description = ''
        How often or when to run agnos.

        The format is described in
        {manpage}`systemd.time(7)`.
      '';
    };

    temporarilyOpenFirewall = mkOption {
      type = types.bool;
      default = false;
      description = ''
        When `true`, will open the port specified in `settings.dns_listen_addr`
        before running the agnos service, and close it when agnos finishes running.
      '';
    };

    group = mkOption {
      type = types.str;
      default = name;
      description = ''
        Group to run Agnos as. The acquired certificates will be owned by this group.
      '';
    };

    user = mkOption {
      type = types.str;
      default = name;
      description = ''
        User to run Agnos as. The acquired certificates will be owned by this user.
      '';
    };
  };

  config =
    let
      configFile = format.generate "agnos.toml" cfg.settings;
      port = lib.toInt (lib.last (builtins.split ":" cfg.settings.dns_listen_addr));

      useNftables = config.networking.nftables.enable;

      # nftables implementation for temporarilyOpenFirewall
      fwmark = "0x61676e6f";
      nftablesSetup = pkgs.writeScript "agnos-fw-setup" ''
        #! ${pkgs.nftables}/bin/nft -f
        table inet agnos {
          chain input {
            # Run before NixOS firewall and mark packets to accept
            type filter hook input priority filter - 1;
            meta l4proto { tcp, udp } th dport ${toString port} counter mark set ${fwmark}
          }
        }
      '';
      nftablesTeardown = pkgs.writeScript "agnos-fw-teardown" ''
        #! ${pkgs.nftables}/bin/nft -f
        table inet agnos
        delete table inet agnos
      '';

      # iptables implementation for temporarilyOpenFirewall
      helpers = ''
        function ip46tables() {
          ${pkgs.iptables}/bin/iptables -w "$@"
          ${pkgs.iptables}/bin/ip6tables -w "$@"
        }
      '';
      fwFilter = ''--dport ${toString port} -j ACCEPT -m comment --comment "agnos"'';
      iptablesSetup = pkgs.writeShellScript "agnos-fw-setup" ''
        ${helpers}
        ip46tables -I INPUT 1 -p tcp ${fwFilter}
        ip46tables -I INPUT 1 -p udp ${fwFilter}
      '';
      iptablesTeardown = pkgs.writeShellScript "agnos-fw-setup" ''
        ${helpers}
        ip46tables -D INPUT -p tcp ${fwFilter}
        ip46tables -D INPUT -p udp ${fwFilter}
      '';
    in
    lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.temporarilyOpenFirewall || config.networking.firewall.enable;
          message = "temporarilyOpenFirewall is only useful when firewall is enabled";
        }
      ];

      networking.firewall.extraInputRules = lib.mkIf (cfg.temporarilyOpenFirewall && useNftables)
        ''meta mark ${fwmark} counter accept comment "accept agnos marked packets"'';

      systemd.services.agnos = {
        serviceConfig = {
          ExecStartPre =
            lib.optional cfg.generateKeys.enable ''
              ${pkgs.agnos}/bin/agnos-generate-accounts-keys \
                --no-confirm \
                --key-size ${toString cfg.generateKeys.keySize} \
                ${configFile}
            '' ++
            lib.optional
              cfg.temporarilyOpenFirewall
              ("+" + (if useNftables then nftablesSetup else iptablesSetup));
          ExecStopPost = lib.optional cfg.temporarilyOpenFirewall
            ("+" + (if useNftables then nftablesTeardown else iptablesTeardown));
          ExecStart = ''
            ${pkgs.agnos}/bin/agnos \
              ${if cfg.server != null then "--acme-url=${cfg.server}" else "--no-staging"} \
              ${lib.optionalString (cfg.serverCa != null) "--acme-serv-ca=${cfg.serverCa}"} \
              ${configFile}
          '';
          Type = "oneshot";
          User = cfg.user;
          Group = cfg.group;
          StateDirectory = name;
          StateDirectoryMode = "0750";
          WorkingDirectory = "${stateDir}";

          # Allow binding privileged ports if necessary
          CapabilityBoundingSet = lib.mkIf (port < 1024) [ "CAP_NET_BIND_SERVICE" ];
          AmbientCapabilities = lib.mkIf (port < 1024) [ "CAP_NET_BIND_SERVICE" ];
        };

        after = [ "firewall.target" "network-online.target" ];
        wants = [ "network-online.target" ];
      };

      systemd.timers.agnos = {
        timerConfig = {
          OnCalendar = cfg.startAt;
          Persistent = cfg.persistent;
          Unit = "agnos.service";
        };
        wantedBy = [ "timers.target" ];
      };

      users.groups = lib.mkIf (cfg.group == name) {
        ${cfg.group} = { };
      };

      users.users = lib.mkIf (cfg.user == name) {
        ${cfg.user} = {
          isSystemUser = true;
          description = "Agnos service user";
          group = cfg.group;
        };
      };
    };
}
