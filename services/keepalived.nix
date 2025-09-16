{
  lib,
  pkgs,
  host,
  vrrp,
  ...
}:
{
  services.keepalived = {
    enable = true;
    package = pkgs.keepalived;

    openFirewall = true;

    vrrpInstances.pihole_vrrp = {
      state = "MASTER";
      interface = host.eth;
      virtualRouterId = 254;
      priority = 255;
      extraConfig = ''
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass ${vrrp.pass}
        }
      '';
      virtualIps = lib.singleton {
        addr = vrrp.addr;
        dev = host.eth;
      };
    };
  };
}
