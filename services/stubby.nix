{
  config,
  lib,
  ...
}:
let
  cfg = config.pihole.stubby;
in
{
  options.pihole.stubby.port = lib.mkOption {
    description = "Listen port for Stubby";
    default = "5153";
    example = "5153";
    type = lib.types.str;
  };

  config = {
    services.stubby = {
      enable = true;

      # 0 - emerg
      # 1 - alert
      # 2 - crit
      # 3 - error
      # 4 - warning
      # 5 - notice
      # 6 - info
      # 7 - debug
      logLevel = 0;

      settings = {
        ### BASIC & PRIVACY SETTINGS
        # Specifies whether to run as a recursive or stub resolver
        # For stubby this MUST be set to GETDNS_RESOLUTION_STUB
        resolution_type = "GETDNS_RESOLUTION_STUB";

        # Ordered list composed of one or more transport protocols:
        # GETDNS_TRANSPORT_UDP, GETDNS_TRANSPORT_TCP or GETDNS_TRANSPORT_TLS
        # If only one transport value is specified it will be the only transport used.
        # Should it not be available basic resolution will fail.
        # Fallback transport options are specified by including multiple values in the
        # list.  Strict mode (see below) should use only GETDNS_TRANSPORT_TLS.
        dns_transport_list = [ "GETDNS_TRANSPORT_TLS" ];

        # Selects Strict or Opportunistic Usage profile as described in
        # https://datatracker.ietf.org/doc/draft-ietf-dprive-dtls-and-tls-profiles/
        # ONLY for the case when TLS is the one and only transport specified above.
        # Strict mode requires that authentication information for the upstreams is
        # specified below. Opportunistic may fallback to clear text DNS if UDP or TCP
        # is included in the transport list above.
        # For Strict use        GETDNS_AUTHENTICATION_REQUIRED
        # For Opportunistic use GETDNS_AUTHENTICATION_NONE
        tls_authentication = "GETDNS_AUTHENTICATION_REQUIRED";

        # EDNS0 option to pad the size of the DNS query to the given blocksize
        # 128 is currently recommended by
        # https://tools.ietf.org/html/draft-ietf-dprive-padding-policy-03
        tls_query_padding_blocksize = 128;

        # EDNS0 option for ECS client privacy as described in Section 7.1.2 of
        # https://tools.ietf.org/html/rfc7871
        # If you really want to use a resolver that sends ECS (such as Google or one of
        # the Quad9 ones) in order to gain better geo-location of content, then be aware
        # that this will expose a portion of your IP address in queries to some
        # authoritative servers. You will need to configure that server and also set this
        # parameter to 0 to fully enable ECS.
        edns_client_subnet_private = 1;

        ### CONNECTION SETTINGS
        # Set to 1 to instruct stubby to distribute queries across all available name
        # servers - this will use multiple simultaneous connections which can give
        # better performance in most (but not all) cases.
        # Set to 0 to treat the upstreams below as an ordered list and use a single
        # upstream until it becomes unavailable, then use the next one.
        round_robin_upstreams = 1;

        # EDNS0 option for keepalive idle timeout in milliseconds as specified in
        # https://tools.ietf.org/html/rfc7828
        # This keeps idle TLS connections open to avoid the overhead of opening a new
        # connection for every query. Note that if a given server doesn't implement
        # EDNS0 keepalive and uses an idle timeout shorter than this stubby will backoff
        # from using that server because the server is always closing the connection.
        # This can degrade performance for certain configurations so reducing the
        # idle_timeout to below that of that lowest server value is recommended.
        # Default is 10000
        idle_timeout = 10000;

        ### LISTEN ADDRESS
        # Set the listen addresses for the stubby DAEMON. This specifies localhost IPv4
        # and IPv6. It will listen on port 53 by default. Use <IP_address>@<port> to
        # specify a different port. (Note that due to restrictions within the config
        # file parser, IPv6 address cannot start with `::` )
        listen_addresses = [ "127.0.0.1@${cfg.port}" ];

        ### UPSTREAMS
        # Specify the list of upstream recursive name servers to send queries to
        # In Strict mode upstreams need either a tls_auth_name or a tls_pubkey_pinset
        # so the upstream can be authenticated.
        ###############################################################################
        ####  Users are recommended to use more than one upstream for robustness  #####
        ###############################################################################
        # You can enable other resolvers by uncommenting the relevant
        # section below or adding their information directly. Also see this list for
        # other test servers: https://dnsprivacy.org/wiki/display/DP/DNS+Privacy+Test+Servers
        #
        # In Opportunistic mode they only require an IP address in address_data.
        # The information for an upstream can include the following:
        # - address_data: IPv4 or IPv6 address of the upstream
        #   port: Port for UDP/TCP (default is 53)
        #   tls_auth_name: Authentication domain name checked against the server
        #                  certificate
        #   tls_pubkey_pinset: An SPKI pinset verified against the keys in the server
        #                      certificate
        #     - digest: Only "sha256" is currently supported
        #       value: Base64 encoded value of the sha256 fingerprint of the public
        #              key
        #   tls_port: Port for TLS (default is 853)
        #
        # To always use the DHCP resolvers provided by the local network in Opportunistic
        # mode then
        # 1) In the dns_transport_list after TLS add UDP then TCP
        # 2) Change to tls_authentication: GETDNS_AUTHENTICATION_NONE
        # 3) Remove all the upstream_recursive_servers listed below
        upstream_recursive_servers = [
          ## Quad 9 'secure' service - Filters, does DNSSEC, doesn't send ECS
          {
            address_data = "9.9.9.9";
            #address_data = "2620:fe::fe"; # IPv6
            tls_auth_name = "dns.quad9.net";
          }
          {
            address_data = "149.112.112.112";
            #address_data = "2620:fe::9"; # IPv6
            tls_auth_name = "dns.quad9.net";
          }

          ## Quad 9 'secure w/ECS' service - Filters, does DNSSEC, DOES send ECS
          ## See the entry for `edns_client_subnet_private` for more details on ECS
          /*
            {
              address_data = "9.9.9.11";
              tls_auth_name = "dns11.quad9.net";
            }
            {
              address_data = "149.112.112.11";
              tls_auth_name = "dns11.quad9.net";
            }
          */

          ## Quad 9 'insecure' service - No filtering, no DNSSEC, doesn't send ECS
          /*
            {
              address_data = "9.9.9.10";
              tls_auth_name = "dns10.quad9.net";
            }
            {
              address_data = "149.112.112.10";
              tls_auth_name = "dns10.quad9.net";
            }
          */

          ## Cloudflare 1.1.1.1 and 1.0.0.1
          ## (NOTE: recommend reducing idle_timeout to 9000 if using Cloudflare)
          /*
            {
              address_data = "1.1.1.1";
              tls_auth_name = "cloudflare-dns.com";
            }
            {
              address_data = "1.0.0.1";
              tls_auth_name = "cloudflare-dns.com";
            }
          */

          ## Google
          /*
            {
              address_data = "8.8.8.8";
              tls_auth_name = "dns.google";
            }
            {
              address_data = "8.8.4.4";
              tls_auth_name = "dns.google";
            }
          */

          ## Adguard Default servers
          /*
            {
              address_data = "94.140.14.14";
              tls_auth_name = "dns.adguard-dns.com";
            }
            {
              address_data = "94.140.15.15";
              tls_auth_name = "dns.adguard-dns.com";
            }
          */

          ## Adguard Family Protection servers
          /*
            {
              address_data = "94.140.14.15";
              tls_auth_name = "family.adguard-dns.com";
            }
            {
              address_data = "94.140.15.16";
              tls_auth_name = "family.adguard-dns.com";
            }
          */
        ];
      };
    };
  };
}
