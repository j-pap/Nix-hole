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
    extraGlobalDefs = ''
      max_auto_priority 99
      router_id ${host.name}
    '';

    vrrpInstances.PIHOLE = {
      state = "MASTER";
      interface = host.eth;
      virtualRouterId = 254;
      priority = 255;
      unicastSrcIp = host.ip;
      unicastPeers = [
        vrrp.backup.ip
      ];
      extraConfig = ''
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass ${vrrp.pass}
        }
      '';
      virtualIps = lib.singleton {
        addr = vrrp.addr;
      };
    };
  };
}
