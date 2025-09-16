{
  config,
  lib,
  pkgs,
  ...
}:
{
  boot.kernel.sysctl."net.core.rmem_max" = 1048576;

  services.unbound = {
    enable = true;
    package = pkgs.unbound-with-systemd;
    user = "unbound";
    group = "unbound";

    stateDir = "/var/lib/unbound";
    resolveLocalQueries = true;
    settings = {
      forward-zone = lib.singleton {
        name = ".";
        forward-addr = [
          # DoT - stubby
          "127.0.0.1@${config.pihole.stubby.port}"
          # DoH - cloudflared
          "127.0.0.1@${config.pihole.cloudflared.port}"
        ];
      };

      server = {
        ### PI-HOLE ###
        # If no logfile is specified, syslog is used
        #logfile = "/var/log/unbound/unbound.log";
        verbosity = 0;

        interface = "127.0.0.1";
        port = 5335;
        do-ip4 = true;
        do-udp = true;
        do-tcp = true;

        # May be set to no if you don't have IPv6 connectivity
        do-ip6 = false;
        # You want to leave this to no unless you have *native* IPv6. With 6to4 and
        # Terredo tunnels your web browser should favor IPv4 for the same reasons
        prefer-ip6 = false;

        # Use this only when you downloaded the list of primary root servers!
        # If you use the default dns-root-data package, unbound will find it automatically
        root-hints = "${pkgs.dns-root-data.out}/root.hints";

        # Trust glue only if it is within the server's authority
        harden-glue = true;
        # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
        harden-dnssec-stripped = true;

        # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
        # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
        use-caps-for-id = false;

        # Reduce EDNS reassembly buffer size.
        # IP fragmentation is unreliable on the Internet today, and can cause
        # transmission failures when large DNS messages are sent via UDP. Even
        # when fragmentation does work, it may not be secure; it is theoretically
        # possible to spoof parts of a fragmented DNS message, without easy
        # detection at the receiving end. Recently, there was an excellent study
        # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
        # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
        # in collaboration with NLnet Labs explored DNS using real world data from the
        # the RIPE Atlas probes and the researchers suggested different values for
        # IPv4 and IPv6 and in different scenarios. They advise that servers should
        # be configured to limit DNS messages sent over UDP to a size that will not
        # trigger fragmentation on typical network links. DNS servers can switch
        # from UDP to TCP when a DNS response is too big to fit in this limited
        # buffer size. This value has also been suggested in DNS Flag Day 2020.
        edns-buffer-size = 1232;

        # Perform prefetching of close to expired message cache entries
        # This only applies to domains that have been frequently queried
        prefetch = true;

        # One thread should be sufficient, can be increased on beefy machines.
        # In reality for most users running on small networks or on a single machine,
        # it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
        num-threads = 1;

        # Ensure kernel buffer is large enough to not lose messages in traffic spikes
        so-rcvbuf = "1m";

        private-address = [
          # Ensure privacy of local IP ranges
          "192.168.0.0/16"
          "169.254.0.0/16"
          "172.16.0.0/12"
          "10.0.0.0/8"
          "fd00::/8"
          "fe80::/10"
          # Ensure no reverse queries to non-public IP ranges (RFC6303 4.2)
          "192.0.2.0/24"
          "198.51.100.0/24"
          "203.0.113.0/24"
          "255.255.255.255/32"
          "2001:db8::/32"
        ];

        ### CUSTOM ###
        # The time to live (TTL) value lower bound, in seconds. Default 0.
        # If more than an hour could easily give trouble due to stale data.
        cache-min-ttl = 0;

        # This attempts to reduce latency by serving the outdated record before
        # updating it instead of the other way around. Alternative is to increase
        # cache-min-ttl to e.g. 3600. Default no
        serve-expired = true;

        # Limit serving of expired responses to configured seconds after
        # expiration. 0 disables the limit. Default 86400
        #serve-expired-ttl = 3600;

        # The amount of memory to use for the message/RRset cache
        # Plain value in bytes or you can append k, m or G. Defaults "4m"
        msg-cache-size = "128m";
        rrset-cache-size = "256m";

        # If yes, localhost is added to the do-not-query-address  entries,
        # both  IP6  ::1 and IP4 127.0.0.1/8. If no, then localhost can be
        # used to send queries to. Default is yes.
        do-not-query-localhost = "no";
      };
    };
  };
}
