{
  config,
  lib,
  pkgs,
  domain,
  host,
  network,
  pihole,
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
    services = {
      pihole-ftl = {
        enable = true;
        package = pkgs.pihole-ftl;
        piholePackage = pkgs.pihole;
        user = "pihole";
        group = "pihole";

        openFirewallDHCP = lib.mkIf (cfg.dhcp.enable) true; # Port 67
        openFirewallDNS = true; # Port 53
        openFirewallWebserver = true; # Ports in 'settings.webserver.port'

        lists = [
          {
            description = "Default";
            enabled = true;
            url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
            type = "block";
          }
          {
            description = "Hagezi multi-pro";
            enabled = true;
            url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
            type = "block";
          }
          {
            description = "EasyList";
            enabled = false;
            url = "https://v.firebog.net/hosts/Easylist.txt";
            type = "block";
          }
        ];

        macvendorURL = "https://ftl.pi-hole.net/macvendor.db";
        stateDirectory = "/var/lib/pihole";
        logDirectory = "/var/log/pihole";
        queryLogDeleter = {
          enable = true;
          age = 90;
          interval = "weekly";
        };
        #useDnsmasqConfig = false;
        #privacyLevel = 0; # 0=full | 1=hide domains | 2=hide domains/clients | 3=anonymous - Default is 0

        settings = {
          dns = {
            upstreams = [
              # Upstream DNS servers to forward requests to
              "127.0.0.1#${unbound.port}"
            ];
            ignoreLocalhost = true; # Hide queries made by localhost - Default is false
            piholePTR = "HOSTNAME"; # PI.HOLE | HOSTNAME | HOSTNAMEFQDN | NONE - Default is 'PI.HOLE'
            domainNeeded = true; # Never forward non-FQDN A/AAAA queries to upstream nameservers - Default is false
            interface = host.eth; # Network interface to use
            listeningMode = "ALL"; # LOCAL | SINGLE | BIND | ALL | NONE - Default is 'LOCAL'
            revServers = [
              # Conditional forwarding
              #"<enabled>,<ip-address[/prefix-len]>,<server[#port]>[,<domain>]"
              "true,${network.cidr},${network.dg},home.arpa"
            ];

            domain.name = domain; # Default is 'lan'
            cache.size = 0; # DNS server cache size - Default is 10000
          };

          dhcp = lib.optionalAttrs (cfg.dhcp.enable) {
            active = cfg.dhcp.enable; # DHCP service
          };

          ntp = {
            ipv4.active = cfg.ntp.enable; # IPv4 NTP service - Default is true
            ipv6.active = cfg.ntp.enable; # IPv6 NTP service - Default is true
          };

          webserver = {
            domain = config.services.pihole-web.hostName;
            port = config.services.pihole-web.ports;

            /*
              # Need to test if setting the paths is still required
              paths =
                let
                  web-admin = pkgs.runCommand "pihole-web-admin" { } ''
                    mkdir -p "$out"
                    ln -sf ${pkgs.pihole-web}/share "$out"/admin
                  '';
                in
                {
                  webroot = lib.mkForce web-admin;
                  webhome = lib.mkForce "/admin/";
                };
            */

            api = {
              pwhash = pihole.pwhash; # Hashed web interface/API password
              totp_secret = pihole.totp; # 2FA TOTP secret
              app_pwhash = pihole.apphash; # Hashed application password
            };
          };

          misc.dnsmasq_lines = [
            # Split DNS
            #"address=/domain.tld/local_ip"
            "address=/${domain}/${webServer.ip}"
          ];
        };
      };

      pihole-web = {
        enable = true;
        package = pkgs.pihole-web;
        hostName = "pihole.${domain}"; # On which domain is the web interface served - Default is 'pi.hole'
        ports = [
          # Web interface ports - Defaults are '80o,443os,[::]:80o,[::]:443os'
          "80o"
          "443os"
          #"[::]:80o"
          #"[::]:443os"
        ];
      };
    };

    systemd.services = {
      /*
        # Nix module now adds macvendor.db automatically? - need to test
        pihole-ftl-setup.preStart =
          let
            stateDir = config.services.pihole-ftl.stateDirectory;
          in
          ''
            if [ ! -f ${stateDir}/macvendor.db ]; then
              DIR=$(mktemp -d)
              ${lib.getExe pkgs.curl} -sSL "https://ftl.pi-hole.net/macvendor.db" -o "$DIR"/macvendor.db
              ${lib.getExe' pkgs.toybox "install"} -m 0664 -o pihole -g pihole "$DIR"/macvendor.db ${stateDir}/macvendor.db
            fi
          '';
      */

      pihole-gravity-update = {
        after = [ "pihole-ftl-setup.service" ];
        path = [ pkgs.pihole ];
        script = "pihole -g";
        startAt = "weekly";
      };
    };
  };
}
