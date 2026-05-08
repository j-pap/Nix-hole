final: prev:
{
  nix-plugins =
    let
      getNixVer =
        v:
        final.lib.concatStringsSep "_" [
          "${final.lib.versions.major v}"
          "${final.lib.versions.minor v}"
        ];
    in
      prev.nix-plugins.override {
        nixComponents = final.nixVersions."nixComponents_${getNixVer final.nix.version}";
      };

  pihole = prev.pihole.unresholved.overrideAttrs (
    finalAttrs: oldAttrs:
    {
      version = "6.4.2";
      src = oldAttrs.src.overrideAttrs {
        tag = "v${finalAttrs.version}";
        hash = "sha256-A34LLXI+hmDNXN4MoLLlC9tW3xx+v/1La/qzFSDW0xQ=";
      };
      meta = oldAttrs.meta // {
        changelog = "https://github.com/pi-hole/pi-hole/releases/tag/v${finalAttrs.version}";
      };
    }
  );

  /*
    # Does not currently build due to upstream gcc error
    pihole-ftl = prev.pihole-ftl.overrideAttrs (
      oldAttrs: {
        version = "6.6.1";
        src = oldAttrs.src.overrideAttrs {
          hash = "sha256-UMLTym9LSx8rlWKkFtHGtSEM0Stdpkfkz/7Iy/05jf8=";
        };
      }
    );
  */

  pihole-web = prev.pihole-web.overrideAttrs (
    oldAttrs: {
      version = "6.5";
      src = oldAttrs.src.overrideAttrs {
        hash = "sha256-ozMqgxyYBDNeYGnZIhql7hnF8D/PwqAe9ypUkkUfKBc=";
      };
    }
  );
}
