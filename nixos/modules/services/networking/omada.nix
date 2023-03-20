{ config, options, lib, pkgs, utils, ... }:
let
  cfg = config.services.omada;
  logDir = "/var/log/omada";
  stateDir = "/var/lib/omada";
in
{
  options = with lib; {
    services.omada.enable = mkEnableOption (lib.mdDoc "Omada controller");

    services.omada.jrePackage = mkOption {
      type = types.package;
      default = pkgs.jre8;
      defaultText = literalExpression "pkgs.jre8";
      description = lib.mdDoc ''
        The JRE package to use. Check the release notes to ensure it is supported.
      '';
    };

    services.omada.mongodbPackage = mkOption {
      type = types.package;
      default = pkgs.mongodb-4_2;
      defaultText = literalExpression "pkgs.mongodb";
      description = lib.mdDoc ''
        The mongodb package to use. Please note: Omada officially only supports mongodb up until 3.6 but works with 4.2.
      '';
    };

    # TODO: implement
    services.omada.openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc ''
        Whether or not to open the minimum required ports on the firewall.

        This is necessary to allow firmware upgrades and device discovery to
        work. For remote login, you should additionally open (or forward) port
        8043.
      '';
    };

    services.omada.initialJavaHeapSize = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 1024;
      description = lib.mdDoc ''
        Set the initial heap size for the JVM in MB. If this option isn't set, the
        JVM will decide this value at runtime.
      '';
    };

    services.omada.maximumJavaHeapSize = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 4096;
      description = lib.mdDoc ''
        Set the maximum heap size for the JVM in MB. If this option isn't set, the
        JVM will decide this value at runtime.
      '';
    };

  };

  config = lib.mkIf cfg.enable {

    users.users.omada = {
      isSystemUser = true;
      group = "omada";
      description = "Omada controller daemon user";
      home = "${stateDir}";
    };
    users.groups.omada = { };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedUDPPorts = [ 29810 ];
      allowedTCPPortRanges = [{ from = 29811; to = 29814; }];
    };

    systemd.services.omada = {
      description = "Omada controller daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      # Make sure package upgrades trigger a service restart
      restartTriggers = [ pkgs.omada-controller cfg.mongodbPackage ];

      path = [ pkgs.bash pkgs.procps ];
      script = ''
        mkdir -p ../data/{db,keystore,pdf}
        ln -sf ${pkgs.omada-controller}/data/html ../data/html

        exec ${pkgs.jsvc}/bin/jsvc \
          -nodetach \
          -cwd /home/justinas/omada/data \
          -home ${cfg.jrePackage}/lib/openjdk \
          -pidfile /dev/null \
          -cp ${pkgs.commonsDaemon}/share/java/commons-daemon-${pkgs.commonsDaemon.version}.jar:${stateDir}/lib/*:${stateDir}/properties \
          -outfile ${logDir}/startup.log \
          -errfile ${logDir}/startup.log \
          -server \
          -Djava.awt.headless=true \
          com.tplink.smb.omada.starter.OmadaLinuxMain start
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        TimeoutSec = "5min";
        User = "omada";
        UMask = "0077";
        WorkingDirectory = "${stateDir}/lib";

        # Hardening
        AmbientCapabilities = "";
        CapabilityBoundingSet = "";
        # ProtectClock= adds DeviceAllow=char-rtc r
        DeviceAllow = "";
        DevicePolicy = "closed";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallErrorNumber = "EPERM";
        SystemCallFilter = [ "@system-service" ];

        StateDirectory = "omada";
        RuntimeDirectory = "omada";
        LogsDirectory = "omada";

        # We must create the binary directories as bind mounts instead of symlinks
        # This is because the controller resolves all symlinks to absolute paths
        # to be used as the working directory.
        BindPaths = [
          "/var/log/omada:${stateDir}/logs"
          "${pkgs.omada-controller}/bin:${stateDir}/bin"
          "${pkgs.omada-controller}/lib:${stateDir}/lib"
          "${pkgs.omada-controller}/properties:${stateDir}/properties"
        ];
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ justinas ];
}
