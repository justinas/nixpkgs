{ config, lib, pkgs, ... }:
let
  cfg = config.services.alertmanager-discord;
in
{
  options.services.alertmanager-discord = with lib; {
    enable = mkEnableOption "alertmanager-discord";

    discordWebhook = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://discord.com/api/webhooks/880147380966321/HycCH_DMzkD5zXASVVvj3QRXHUnxs0pxuRzSbBs_UH7p71PS_AXD002Mq";
      description = ''
        The URL of the Discord webhook to use to post messages.
        Note that webhooks require no additional authentication,
        and this option will put the webhook's URL in the world-readable Nix store.
        Consider using <literal>discordWebhookFile</literal> instead.
      '';
    };

    discordWebhookFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/alertmanager-discord-webhook";
      description = ''
        The path of a file to read the Discord webhook URL from.
        Mutually exclusive with <literal>discordWebhook</literal>.
      '';
    };

    listenAddress = mkOption {
      type = types.str;
      default = "0.0.0.0:19094";
      example = "127.0.0.1:9094";
      description = ''
        The address on which alertmanager-discord listens
        for incoming requests from Alertmanager.

        Default is listening on port 19094 of all IPv4 addresses.
        Note that the upstream uses port 9094 by default,
        but that conflicts with the default port of Alertmanager's clustering API.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.discordWebhook == null) != (cfg.discordWebhookFile == null);
        message = "Exactly one of services.alertmanager-discord.discordWebhook and services.alertmanager-discord.discordWebhookFile must be set.";
      }
    ];

    systemd.services.alertmanager-discord = {
      environment = {
        LISTEN_ADDRESS = cfg.listenAddress;
      } // lib.optionalAttrs (cfg.discordWebhook != null) { DISCORD_WEBHOOK = cfg.discordWebhook; };

      serviceConfig = {
        DynamicUser = true;
        LoadCredential = lib.optionalString (cfg.discordWebhookFile != null) "webhook:${cfg.discordWebhookFile}";
      };
      script = ''
        ${lib.optionalString (cfg.discordWebhookFile != null) ''export DISCORD_WEBHOOK=$(cat "$CREDENTIALS_DIRECTORY/webhook")''}
        exec ${pkgs.alertmanager-discord}/bin/alertmanager-discord
      '';
    };
  };
}
