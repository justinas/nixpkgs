{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types literalExample;

  cfg = config.services.isso;

  settingsFormat = pkgs.formats.ini { };
  configFile = settingsFormat.generate "isso.conf" cfg.settings;
in {

  options = {
    services.isso = {
      address = mkOption {
        description = ''
          The address for isso server to listen on
        '';
        default = "localhost";
        type = types.str;
      };

      enable = mkEnableOption ''
        A commenting server similar to Disqus.
      '';

      gunicorn.workers = mkOption {
        type = types.ints.positive;
        default = 3;
        example = 10;
        description = ''
          The number of worker processes for handling requests.
        '';
      };

      port = mkOption {
        description = ''
          The port for isso server to listen on
        '';
        default = 8080;
        type = types.port;
      };

      settings = mkOption {
        description = ''
          Configuration for <package>isso</package>.

          See <link xlink:href="https://posativ.org/isso/docs/configuration/server/">Isso Server Configuration</link>
          for supported values.
        '';

        type = types.submodule {
          freeformType = settingsFormat.type;
        };

        example = literalExample ''
          {
            general = {
              "max-age" = "15m";
            };
          }
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    services.isso.settings.general.dbpath = lib.mkDefault "/var/lib/isso/comments.db";

    systemd.services.isso = {
      description = "isso, a commenting server similar to Disqus";
      wantedBy = [ "multi-user.target" ];

      environment = {
        ISSO_SETTINGS = configFile;
      };

      serviceConfig = {
        User = "isso";
        Group = "isso";

        DynamicUser = true;

        StateDirectory = "isso";

        ExecStart =
          let
            bindAddr = "${cfg.address}:${toString cfg.port}";
            python = pkgs.python3.withPackages (ps: [ pkgs.isso ps.gunicorn ]);
          in
          ''
            ${python}/bin/python -m gunicorn -b ${bindAddr} --preload -w ${toString cfg.gunicorn.workers} isso.run
          '';

        Restart = "on-failure";
        RestartSec = 1;
      };
    };
  };
}
