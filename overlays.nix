final: prev: {
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

  # 6.5 errors when building - defaults to 6.4.2
  /*
    pihole =
      let
        version = "6.5";
        pkgOverride = prev.pihole.unresholved.overrideAttrs (oldAttrs: {
          version = version;
          src = oldAttrs.src.overrideAttrs {
          hash = "sha256-pjfMA8TOuvr3YdBjGS6WITy+gVfN0XoaVOV5cJl8Ni4=";
          };
        });
      in
      prev.pihole.overrideAttrs (oldAttrs: {
        version = version;
        src = pkgOverride;
        passthru = (oldAttrs.passthru or { }) // {
          unresholved = pkgOverride;
        };
      });
  */

  pihole-ftl = prev.pihole-ftl.overrideAttrs (oldAttrs: {
    version = "6.8";
    src = oldAttrs.src.overrideAttrs {
      hash = "sha256-KQiQ4qsUSvHGVEGAzNeCG4hcDVRDtJhW8+vNYN75LAY=";
    };
  });

  pihole-web = prev.pihole-web.overrideAttrs (oldAttrs: {
    version = "6.6.1";
    src = oldAttrs.src.overrideAttrs {
      hash = "sha256-z1SAQr3ZMiN2A3p0iYYa9AgNqydIZhxCqRK66nw2xYA=";
    };
  });
}
