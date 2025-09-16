# Using Docker for now, as the Nix service seems to still need work
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
  stateDirectory = config.services.pihole-ftl.stateDirectory;
  unbound.port = toString config.services.unbound.settings.server.port;
in
{
  services = {
    # https://github.com/NixOS/nixpkgs/issues/429395
    # Using 'services.pihole-ftl.settings.misc.dnsmasq_lines' instead
    #dnsmasq.settings.address = "/${domain}/${webServer.ip}"; # Split DNS

    pihole-ftl = {
      enable = true;
      package = pkgs.pihole-ftl;
      piholePackage = pkgs.pihole;
      user = "pihole";
      group = "pihole";

      stateDirectory = "/var/lib/pihole";
      logDirectory = "/var/log/pihole";
      openFirewallDNS = true; # Open port 53
      openFirewallWebserver = true; # Open ports in 'settings.webserver.port'
      privacyLevel = 0; # 0 - full | 1 - hide domains | 2 - hide domains/clients | 3 - anonymous
      #useDnsmasqConfig = true; # Import options defined in services.dnsmasq.settings via misc.dnsmasq_lines in Pi-hole’s config

      queryLogDeleter = {
        enable = true;
        age = 30;
        interval = "weekly";
      };

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

      settings = {
        dns = {
          bogusPriv = true;       # All reverse lookups for private IP ranges are not forwarded upstream - Default is true
          cache.size = 0;         # DNS server cache size - Default is 10000
          domain = "home.arpa";   # Default is 'lan'
          domainNeeded = true;    # Never forward non-FQDN A/AAAA queries to upstream nameservers - Default is false
          expandHosts = true;     # Domain is appended to host's hostname - Default is false
          ignoreLocalhost = true; # Hide queries made by localhost - Default is false
          interface = host.eth;   # Network interface to use
          listeningMode = "ALL";  # LOCAL | SINGLE | BIND | ALL | NONE - Default is local
          piholePTR = "HOSTNAME"; # PI.HOLE | HOSTNAME | HOSTNAMEFQDN | NONE - Default is PI.HOLE
          revServers = [
            # Conditional forwarding - "<enabled>,<ip-address[/prefix-len]>,<server[#port]>[,<domain>]"
            "true,${network.cidr},${network.dg},home.arpa"
          ];
          upstreams = [
            # Upstream DNS servers to forward requests to
            "127.0.0.1#${unbound.port}"
          ];
        };

        files.macvendor = lib.mkForce "${stateDirectory}/macvendor.db";

        misc.dnsmasq_lines = [
          "address=/${domain}/${webServer.ip}" # Split DNS
        ];

        ntp = {
          ipv4.active = false; # IPv4 NTP service - Default is true
          ipv6.active = false; # IPv6 NTP service - Default is true
        };

        webserver = {
          #domain = ""; # Set via services.pihole-web.hostName
          #port = ""; # Set via services.pihole-web.ports

          api = {
            # https://github.com/NixOS/nixpkgs/issues/435150
            #pwhash = pihole.pwhash; # Hashed web interface/API password
            #totp_secret = pihole.totp; # 2FA TOTP secret
            #app_pwhash = pihole.apphash; # Hashed application password
          };

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
        };
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
      ];
    };
  };

  systemd.services = {
    pihole-ftl-setup = {
      preStart = ''
        if [ ! -f ${stateDirectory}/macvendor.db ]; then
          DIR=$(mktemp -d)
          ${lib.getExe pkgs.curl} -sSL "https://ftl.pi-hole.net/macvendor.db" -o "$DIR"/macvendor.db
          ${lib.getExe' pkgs.toybox "install"} -m 0664 -o pihole -g pihole "$DIR"/macvendor.db ${stateDirectory}/macvendor.db
        fi
      '';
    };

    pihole-gravity-update = {
      after = [ "pihole-ftl-setup.service" ];
      path = [ pkgs.pihole ];
      script = "pihole -g";
      startAt = "weekly";
    };
  };
}
