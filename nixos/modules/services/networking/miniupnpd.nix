{ config, lib, pkgs, ... }:

with lib;

let
  useNftablesFirewall = config.networking.nftables.enable && config.networking.firewall.enable;

  cfg = config.services.miniupnpd;
  configFile = pkgs.writeText "miniupnpd.conf" ''
    ext_ifname=${cfg.externalInterface}
    enable_natpmp=${if cfg.natpmp then "yes" else "no"}
    enable_upnp=${if cfg.upnp then "yes" else "no"}

    ${concatMapStrings (range: ''
      listening_ip=${range}
    '') cfg.internalIPs}

    ${lib.optionalString (useNftablesFirewall) ''
      upnp_table_name=nixos-fw
      upnp_nat_table_name=miniupnpd-nat
    ''}

    ${cfg.appendConfig}
  '';
  package = pkgs.miniupnpd.override {
    useNftables = useNftablesFirewall;
  };

  nfTablesFwSetup = pkgs.writeShellScript "miniupnpd-nftables-fw-setup" ''
    ${pkgs.nftables}/bin/nft -f - <<EOF
      table inet miniupnpd-nat {
        chain prerouting_miniupnpd {
          type nat hook prerouting priority dstnat;
        }
        chain postrouting_miniupnpd {
          type nat hook postrouting priority srcnat;
        }
      }
    EOF

    # TODO: do this declaratively when #207758 merges
    ${pkgs.nftables}/bin/nft add chain inet nixos-fw miniupnpd
  '';

  nfTablesFwTearDown = pkgs.writeShellScript "miniupnpd-nftables-fw-teardown" ''
    ${pkgs.nftables}/bin/nft -f - <<EOF
      table inet miniupnpd-nat
      delete table inet miniupnpd-nat
    EOF

    # TODO: this will be unnecessary when we add it declaratively
    ${pkgs.nftables}/bin/nft delete chain inet nixos-fw miniupnpd || true
  '';
in
{
  options = {
    services.miniupnpd = {
      enable = mkEnableOption (lib.mdDoc "MiniUPnP daemon");

      externalInterface = mkOption {
        type = types.str;
        description = lib.mdDoc ''
          Name of the external interface.
        '';
      };

      internalIPs = mkOption {
        type = types.listOf types.str;
        example = [ "192.168.1.1/24" "enp1s0" ];
        description = lib.mdDoc ''
          The IP address ranges to listen on.
        '';
      };

      natpmp = mkEnableOption (lib.mdDoc "NAT-PMP support");

      upnp = mkOption {
        default = true;
        type = types.bool;
        description = lib.mdDoc ''
          Whether to enable UPNP support.
        '';
      };

      appendConfig = mkOption {
        type = types.lines;
        default = "";
        description = lib.mdDoc ''
          Configuration lines appended to the MiniUPnP config.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraCommands = lib.optionalString (!config.networking.nftables.enable) ''
      ${pkgs.bash}/bin/bash -x ${package}/etc/miniupnpd/iptables_init.sh -i ${cfg.externalInterface}
    '';

    networking.firewall.extraStopCommands = lib.optionalString (!config.networking.nftables.enable) ''
      ${pkgs.bash}/bin/bash -x ${package}/etc/miniupnpd/iptables_removeall.sh -i ${cfg.externalInterface}'';

    # TODO: this is required to work with filterForward.
    # Do this when #207758 merges and we can do nfTablesFwSetup in `nixos-fw` table declaratively instead.
    # networking.firewall.extraForwardRules = lib.mkIf config.networking.firewall.filterForward "jump miniupnpd";

    systemd.services.miniupnpd = {
      description = "MiniUPnP daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = lib.optional (useNftablesFirewall) nfTablesFwSetup;
        ExecStopPost = lib.optional (useNftablesFirewall) nfTablesFwTearDown;
        ExecStart = "${package}/bin/miniupnpd -f ${configFile}";
        PIDFile = "/run/miniupnpd.pid";
        Type = "forking";
      };
    };
  };
}
