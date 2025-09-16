{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.pihole.cloudflared;
  upstreams = [
  # Quad9
    "https://9.9.9.9/dns-query"
    "https://149.112.112.112/dns-query"
  # Quad9 IPv6
    #"https://[2620:fe::fe]/dns-query"
    #"https://[2620:fe::9]/dns-query"
  # Cloudflare
    #"https://1.1.1.1/dns-query"
    #"https://1.0.0.1/dns-query"
  ];
in
{
  options.pihole.cloudflared.port = lib.mkOption {
    description = "Listen port for Cloudflared";
    default = "5053";
    example = "5053";
    type = lib.types.str;
  };

  config = {
    systemd.services.cloudflared = {
      description = "cloudflared DoH proxy";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = 0;
      };
      script = ''
        ${lib.getExe pkgs.cloudflared} proxy-dns \
          --address 127.0.0.1 \
          --port ${cfg.port} \
        ${lib.concatLines (builtins.map (url: "  --upstream ${url} \\") upstreams)}  &
      '';
    };
  };
}
