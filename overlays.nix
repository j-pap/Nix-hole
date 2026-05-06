final: prev:
let
  getNixVer =
    v:
    final.lib.concatStringsSep "_" [
      "${final.lib.versions.major v}"
      "${final.lib.versions.minor v}"
    ];
in
{
  nix-plugins = prev.nix-plugins.override {
    nixComponents = final.nixVersions."nixComponents_${getNixVer final.nix.version}";
  };

  /*
    pihole = prev.pihole.overrideAttrs (
      finalAttrs: oldAttrs: {
        version = "6.4.2";
        src = oldAttrs.src // {
          tag = "v${finalAttrs.version}";
          hash = final.lib.fakeHash;
        };
      }
    );

    pihole-ftl = prev.pihole-ftl.overrideAttrs (
      finalAttrs: oldAttrs: {
        version = "6.6.1";
        src = oldAttrs.src // {
          tag = "v${finalAttrs.version}";
          hash = final.lib.fakeHash;
        };
      }
    );

    pihole-web = prev.pihole-web.overrideAttrs (
      finalAttrs: oldAttrs: {
        version = "6.5";
        src = oldAttrs.src // {
          tag = "v${finalAttrs.version}";
          hash = final.lib.fakeHash;
        };
      }
    );
  */
}
