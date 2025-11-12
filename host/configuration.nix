{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  host,
  network,
  user,
  secrets,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ] ++ (import ../services);

  ###########################
  ##      CUSTOM ARGS      ##
  ###########################
  _module.args = {
    secrets = (
      assert lib.assertMsg (builtins ? extraBuiltins.readSops)
        "The extraBuiltin 'readSops' could not be read. Verify that 'nix.settings.extra-builtins-file' is defined correctly. This is most likely a 'pkgs.nix-plugins' issue.";
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
    user.name = "pi";
    vrrp = {
      addr = secrets.vrrp.addr;
      pass = secrets.vrrp.pass;
      backup.ip = secrets.vrrp.backup.ip;
    };
    webServer.ip = secrets.web_server.ip;
  };

  ###########################
  ##         BOOT          ##
  ###########################
  boot = {
    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "usbhid"
        "usb_storage"
      ];
      kernelModules = [ ];
    };

    kernelPackages = pkgs.linuxPackages_6_12; # '_rpi4' cannot be used with 'sd-image-aarch64.nix'
    kernelModules = [ ];
    extraModulePackages = [ ];

    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
      timeout = 5;
    };

    supportedFilesystems.zfs = lib.mkForce false;
  };

  sdImage.compressImage = false;

  ###########################
  ##     DOCUMENTATION     ##
  ###########################
  documentation = {
    enable = false;
    dev.enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  ###########################
  ##      ENVIRONMENT      ##
  ###########################
  environment = {
    shellAliases = {
      ".." = "cd ..";
      ".df" = "cd /etc/nixos";
      "ll" = "eza --long --all --header --links --group --modified --git --icons";
      "tree" = "eza --tree --all";
      "rpi-fwflash" = "BOOTFS=/boot/firmware FIRMWARE_RELEASE_STATUS=stable rpi-eeprom-update -d -a";
    };

    systemPackages = builtins.attrValues {
      inherit (pkgs)
        bat
        btop
        eza
        fastfetch
        fd
        file
        ripgrep
        sops
        ssh-to-age
        tldr
        vim
        zellij

        # Hardware
        lshw
        libraspberrypi
        raspberrypi-eeprom

        # Network
        curl
        dig
        speedtest-cli
        traceroute
        wget
        whois

        # Nix
        nixfmt-rfc-style
        nix-tree
        ;
    };

    variables = {
      EDITOR = "vim";
    };
  };

  ###########################
  ##      FILESYSTEM       ##
  ###########################
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
      options = [ "noatime" ];
    };

    # Log2Ram
    "/var/log" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=1G"
      ];
    };
  };

  ###########################
  ##       HARDWARE        ##
  ###########################
  hardware = {
    enableRedistributableFirmware = true;

    deviceTree = {
      enable = true;
      filter = "bcm2711-rpi-4-b.dtb";
      overlays = import ./rpi-dt.nix;
    };

    raspberry-pi."4" = {
      apply-overlays-dtmerge.enable = true;
      gpio.enable = true;
    };
  };

  ###########################
  ##     LOCALIZATION      ##
  ###########################
  console.keyMap = "us";
  i18n.defaultLocale = "en_US.UTF-8";
  time = {
    hardwareClockInLocalTime = true;
    timeZone = "America/Chicago";
  };

  ###########################
  ##      NETWORKING       ##
  ###########################
  networking = {
    enableIPv6 = false;
    hostName = host.name;
    useDHCP = false;

    interfaces.${host.eth}.ipv4.addresses = lib.singleton {
      address = host.ip;
      prefixLength = host.sm;
    };

    nameservers = [
      "127.0.0.1"
    ];

    defaultGateway = {
      address = host.dg;
      interface = host.eth;
    };

    firewall = {
      extraCommands = ''
        iptables -A nixos-fw -p tcp --source ${network.cidr} --dport 22 -j nixos-fw-accept
      '';

      extraStopCommands = ''
        iptables -D nixos-fw -p tcp --source ${network.cidr} --dport 22 -j nixos-fw-accept || true
      '';
    };
  };

  ###########################
  ##          NIX          ##
  ###########################
  nix = {
    optimise.automatic = true;
    registry.nixpkgs.flake = inputs.nixpkgs;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 60d";
    };

    settings = {
      auto-optimise-store = true;
      download-buffer-size = 536870912; # 512MB in Bytes
      experimental-features = [
        "flakes"
        "nix-command"
      ];
      extra-builtins-file = [ "${inputs.self}/secrets/extra-builtins.nix" ];
      max-jobs = 4;
      plugin-files = [ "${pkgs.nix-plugins}/lib/nix/plugins" ];
      substituters = [ ];
      trusted-public-keys = [ ];
      trusted-users = [
        "@wheel"
      ];
    };
  };

  nixpkgs = {
    #config.allowUnfree = true;
    hostPlatform = lib.mkDefault "aarch64-linux";
    overlays = [
      (final: prev: {
        nix-plugins = prev.nix-plugins.overrideAttrs (old: {
          buildInputs = [
            final.boost
            final.nix
          ];
        });
      })
    ];
  };

  system.stateVersion = "25.11";

  ###########################
  ##       PROGRAMS        ##
  ###########################
  programs = {
    git = {
      enable = true;
      package = pkgs.git;
      prompt.enable = true;
      config = {
        commit.gpgSign = true;
        gpg = {
          format = "ssh";
          ssh.allowedSignersFile = "/home/${user.name}/.ssh/allowed_signers";
        };
        init.defaultBranch = "main";
        pull.ff = "only";
        safe.directory = "/etc/nixos";
        user = {
          email = "205946337+j-pap@users.noreply.github.com";
          name = "j-pap";
          signingKey = "/home/${user.name}/.ssh/github_ed25519.pub";
        };
      };
    };

    ssh = {
      startAgent = true;
      extraConfig = ''
        Host github.com
          AddKeysToAgent yes
          IdentitiesOnly yes
          IdentityFile /home/${user.name}/.ssh/github_ed25519
      '';
    };
  };

  ###########################
  ##       SECURITY        ##
  ###########################
  security.sudo = {
    extraConfig = ''Defaults lecture = never'';
    wheelNeedsPassword = true;
  };

  ###########################
  ##       SERVICES        ##
  ###########################
  services = {
    #Log2RAM
    journald.extraConfig = ''
      Storage=volatile
      SystemMaxUse=1G
    '';

    openssh = {
      enable = true;
      openFirewall = false;
      knownHosts = {
        "FW13".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQQSTCKMqWNCTIFsND7Da2EUTjYktXX8xNl7Yf4X4At";
        "T1".publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPiwqkVHyuJgJAdln6Wg7NXip2awN38aXddPydQhTw18";
      };
      settings = {
        #KbdInteractiveAuthentication = false;
        #PasswordAuthentication = false;
        PermitRootLogin = "no";
        UseDns = true;
      };
    };
  };

  ###########################
  ##         SOPS          ##
  ###########################
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = "${inputs.self}/secrets/secrets.nix";
    secrets = { };
    validateSopsFiles = false;
  };

  ###########################
  ##         USERS         ##
  ###########################
  users = {
    mutableUsers = false;
    users = {
      ${user.name} = {
        description = "Raspberry Pi";
        hashedPassword = secrets.user.pass;
        isNormalUser = true;
        extraGroups = [
          "gpio"
          "docker"
          "input"
          "wheel"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAMoEb31xABf0fovDku5zBfBDI2sKCixc31wndQj5VhT"
        ];
      };

      root.initialHashedPassword = "!"; # Disable root login
    };
  };
}
