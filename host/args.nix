{
  lib,
  secrets,
  ...
}:
{
  ###########################
  ##      CUSTOM ARGS      ##
  ###########################
  _module.args = {
    secrets = (
      assert lib.assertMsg (builtins ? extraBuiltins.readSops)
        "The extraBuiltin 'readSops' could not be read. Verify that 'nix.settings.plugin-files' & 'nix.settings.extra-builtins-file' are defined correctly.";
      builtins.extraBuiltins.readSops ../secrets/secrets.nix
    );

    domain = secrets.domain;

    host = {
      name = "pihole1";
      eth = "end0";
      ip = secrets.host.ip;
      sm = secrets.host.subnet;
      dg = secrets.host.gateway;
    };

    network = {
      cidr = secrets.network.cidr;
      dg = secrets.network.gateway;
    };

    pihole = {
      pwhash = secrets.pihole.pwhash;
      totp = secrets.pihole.totp;
      apphash = secrets.pihole.apphash;
    };

    user = {
      name = "pi";
      pass = secrets.user.pass;
    };

    vrrp = {
      addr = secrets.vrrp.addr;
      pass = secrets.vrrp.pass;
      backup.ip = secrets.vrrp.backup.ip;
    };

    webServer.ip = secrets.web_server.ip;
  };
}
