{
  config,
  lib,
  pkgs,
  domain,
  host,
  network,
  pihole,
  user,
  webServer,
  ...
}:
let
  cfg = config.nix-hole.pihole;
  unbound.port = toString config.services.unbound.settings.server.port;
in
{
  options.nix-hole.pihole = {
    dhcp.enable = lib.mkEnableOption "Pihole's DHCP server";
    ntp.enable = lib.mkEnableOption "Pihole's NTP server";
  };

  config = {
    networking.firewall = {
      allowedTCPPorts = [
        53
        80
        443
      ]
      ++ lib.optionals (cfg.dhcp.enable) [
        67
      ]
      ++ lib.optionals (cfg.ntp.enable) [
        123
      ];
      allowedUDPPorts = [ 53 ];
    };

    virtualisation = {
      containers.enable = true;
      oci-containers.backend = "docker";
      docker = {
        enable = true;
        daemon.settings = {
          data-root = "/var/lib/docker";
          default-address-pools = lib.singleton {
            base = "172.17.0.0/12";
            size = 16;
          };
          dns = [ "127.0.0.1" ];
          ipv6 = false;
          live-restore = true;
          log-driver = "journald";
          storage-driver = "overlay2";
        };
      };

      oci-containers.containers = {
        pihole = {
          image = "pihole/pihole:latest";
          pull = "missing"; # always | missing | never | newer
          hostname = host.name;
          autoRemoveOnStop = false;
          autoStart = true;

          capabilities = {
            SYS_NICE = true;
          }
          // lib.optionalAttrs (cfg.dhcp.enable) {
            NET_ADMIN = true;
          }
          // lib.optionalAttrs (cfg.ntp.enable) {
            SYS_TIME = true;
          };

          environment = {
            PIHOLE_UID = "1001"; # Nix UID
            PIHOLE_GID = "100"; # Nix GID

            FTLCONF_dns_cache_size = "0";         # Use Unbound's caching - Default is 10000
            FTLCONF_dns_domain = domain;          # Default is 'lan'
            FTLCONF_dns_domainNeeded = "true";    # Never forward non-FQDN A/AAAA queries to upstream nameservers - Default is false
            FTLCONF_dns_ignoreLocalhost = "true"; # Hide queries made by localhost - Default is false
            FTLCONF_dns_interface = host.eth;     # Network interface to use
            FTLCONF_dns_listeningMode = "ALL";    # LOCAL | SINGLE | BIND | ALL | NONE - Default is local
            FTLCONF_dns_piholePTR = "HOSTNAME";   # PI.HOLE | HOSTNAME | HOSTNAMEFQDN | NONE - Default is PI.HOLE

            # Conditional forwarding - "<enabled>,<ip-address[/prefix-len]>,<server[#port]>[,<domain>]" - separated by semi-colons
            FTLCONF_dns_revServers = ''
              true,${network.cidr},${network.dg},home.arpa
            '';

            # Upstream DNS servers to forward requests to - separated by semi-colons
            FTLCONF_dns_upstreams = ''
              127.0.0.1#${unbound.port}
            '';

            # Split DNS
            FTLCONF_misc_dnsmasq_lines = ''
              address=/${domain}/${webServer.ip}
            '';

            FTLCONF_ntp_ipv4_active = lib.mkIf (cfg.ntp.enable) "true"; # IPv4 NTP service - Default is true
            FTLCONF_ntp_ipv6_active = lib.mkIf (cfg.ntp.enable) "true"; # IPv6 NTP service - Default is true

            FTLCONF_webserver_api_pwhash = pihole.pwhash;      # Hashed web interface password
            FTLCONF_webserver_api_totp_secret = pihole.totp;   # 2FA TOTP secret
            FTLCONF_webserver_api_app_pwhash = pihole.apphash; # Application password
            FTLCONF_webserver_domain = "pihole.${domain}";     # On which domain is the web interface served - Default is 'pi.hole'
            FTLCONF_webserver_port = "80o,443os";              # Web interface ports - Defaults are '80o,443os,[::]:80o,[::]:443os'
          };

          networks = [ "host" ];

          ports = [
            "53:53"
            "53:53/udp"
            "80:80"
            "443:443"
          ]
          ++ lib.optionals (cfg.dhcp.enable) [
            "67:67"
          ]
          ++ lib.optionals (cfg.ntp.enable) [
            "123:123"
          ];

          volumes = [
            "/var/lib/pihole:/etc/pihole"
            "/var/log/pihole:/var/log/pihole"
          ];
        };
      };
    };
  };
}
