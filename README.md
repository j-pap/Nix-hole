# nix-hole
This is a NixOS deployment of Pi-hole, Keepalived, Unbound, Cloudflared, and
Stubby running on a Raspberry Pi 4B.

The main host and network options are sops secrets declared as arguments within
the host/configuration.nix file. This allows them to be referenced throughout
the flake and/or modified easily, if needed.

Each service has a module defined in a services/*.nix file. There are two
files for Pi-hole: one is a Nix module - the other is an OCI Docker container.
As of this writing, the native Nix module seems to have some quirks to it, so
I'm leaving the module as inactive at this time (via services/default.nix) and
using the Docker image instead. I'll revisit the module again in the future to
see if has advanced in development.
