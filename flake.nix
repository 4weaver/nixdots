{
  description = "Home Manager configuration";

  nixConfig = {
    extra-substituters = [
      "https://inogai.cachix.org"
      "https://numtide.cachix.org"
    ];
    extra-trusted-public-keys = [
      "inogai.cachix.org-1:gJVZ8+i50F4/I9/TBnkpBlAGzqzpJQdtK/iQATuWY60="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    ];
  };

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    nixpkgs-old.url = "github:nixos/nixpkgs/release-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Release-pinned home-manager for the arachnet NixOS module: the server's
    # nixos-config pins nixpkgs to release-26.05, so home-manager must match
    # (master tracks nixpkgs-unstable and can drift ahead of the server's
    # nixpkgs). nixpkgs follows the main input so both HM sources stay on the
    # same package set — the NixOS module is evaluated against the consumer's
    # nixpkgs anyway.
    home-manager-release = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-inogai.url = "github:inogai/nvim-inogai";
    sbar-inogai.url = "github:inogai/sbar-inogai";
    nix-yazi-flavors = {
      url = "github:inogai/nix-yazi-flavors";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nix-colors.url = "github:misterio77/nix-colors";
  };

  # ---------------------------------------------------------------------------
  # Presets
  #
  # See the documentation block inside `outputs` below. Presets are defined
  # there (so they are in scope for `mkHome`).
  # ---------------------------------------------------------------------------

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      home-manager-release,
      nur,
      nvim-inogai,
      sbar-inogai,
      nix-yazi-flavors,
      nix-ai-tools,
      nix-colors,
      ...
    }@inputs:
    let
      # Each preset pins the `system` to build for and the `preset` name that
      # `home.nix` consumes to select username, home directory, mac-only
      # packages and module toggles. Switch machine by building a different
      # configuration:
      #
      #   nix build .#homeConfigurations.inogai.activationPackage     # mac
      #   nix build .#homeConfigurations.alexlychen.activationPackage # windows
      #   nix build .#homeConfigurations.arachnet.activationPackage   # arachnet (server)
      #
      # Or with home-manager's standalone CLI:
      #
      #   home-manager switch --flake .#inogai      # mac
      #   home-manager switch --flake .#alexlychen  # windows (WSL)
      #
      # arachnet is consumed as a NixOS module from the nixos-config repo
      # (`nixosModules.inogai-arachnet` below), so no `home-manager switch`
      # on the server — `nixos-rebuild switch` activates it.
      presets = {
        mac = {
          system = "aarch64-darwin";
          preset = "mac";
        };
        windows = {
          system = "x86_64-linux";
          preset = "windows";
        };
        arachnet = {
          system = "x86_64-linux";
          preset = "arachnet";
        };
      };

      # Shared module list. Mac-only modules are safe to import on every
      # preset because they are all guarded by `mkEnableOption` + `mkIf` and
      # only enabled from `home.nix` for the presets that need them.
      sharedModules = [
        nix-colors.homeManagerModules.default
        nvim-inogai.homeModules.default
        ./modules/aerospace
        ./modules/cli-utils
        ./modules/cli-extras
        ./modules/direnv
        ./modules/fonts
        ./modules/gpg
        ./modules/jankyborders
        ./modules/kitty
        ./modules/qutebrowser
        ./modules/shell
        ./modules/sketchybar
        ./modules/syncthing
        ./modules/tui-apps
        ./modules/wsl
        ./modules/yazi
        ./modules/zellij

        ./home.nix
      ];

      # Overlay set shared by every consumer. neovim is the only one that
      # matters on the server; the rest are harmless there because their
      # modules stay disabled (sbar-inogai/qutebrowser are mac-only).
      overlays = [
        nur.overlays.default
        # nvim-inogai's own overlay re-wraps `final.neovim-unwrapped`, which
        # binds the version to whichever nixpkgs the overlay is applied to.
        # Use the pre-built package from nvim-inogai's own nixpkgs instead so
        # the version is pinned regardless of HM's nixpkgs revision.
        (final: prev: {
          neovim = nvim-inogai.packages.${final.system}.neovim;
          sbar-inogai = sbar-inogai.packages.${final.system}.sbar-inogai;
          nix-ai-tools = nix-ai-tools.packages.${final.system};
          qutebrowser = inputs.nixpkgs-old.legacyPackages.${final.system}.qutebrowser;
        })
      ];

      mkHome =
        p:
        let
          pkgs = nixpkgs.legacyPackages.${p.system}.extend (nixpkgs.lib.composeManyExtensions overlays);
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = sharedModules;
          extraSpecialArgs = {
            inherit nix-colors;
            preset = p.preset;
            yaziFlavors = nix-yazi-flavors.packages.${p.system};
          };
        };
    in
    {
      homeConfigurations."inogai" = mkHome presets.mac;
      homeConfigurations."alexlychen" = mkHome presets.windows;
      homeConfigurations."arachnet" = mkHome presets.arachnet;

      # arachnet as a NixOS module: imported by nixos-config's arachnet
      # configuration so `nixos-rebuild switch` activates home-manager along
      # with the system (no separate `home-manager switch` on the server).
      # home-manager-release (release-26.05) matches the consumer's nixpkgs
      # pin. useGlobalPkgs stays off (default) so the neovim overlay can live
      # at the per-user nixpkgs.overlays — home-manager forbids nixpkgs.*
      # options when useGlobalPkgs is true.
      nixosModules = {
        inogai-arachnet = {
          config,
          lib,
          pkgs,
          ...
        }: {
          imports = [ home-manager-release.nixosModules.home-manager ];

          home-manager = {
            useUserPackages = true;
            extraSpecialArgs = {
              inherit nix-colors;
              preset = "arachnet";
              yaziFlavors = nix-yazi-flavors.packages.x86_64-linux;
            };
            users.inogai = {
              imports = sharedModules;
              # The nvim-inogai overlay must reach the user's pkgs; with
              # useGlobalPkgs off, home-manager builds its own pkgs from the
              # system nixpkgs plus these per-user overlays.
              nixpkgs.overlays = overlays;
            };
          };
        };
        default = self.nixosModules.inogai-arachnet;
      };
    };
}
