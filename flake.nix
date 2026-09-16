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
    # arachnet's nixos-config pin (release-26.05 @ 9b69646). Agent standalone
    # homeConfiguration uses this so `home-manager switch` reuses the machine
    # store instead of pulling flakehub weekly.
    nixpkgs-release.url = "github:NixOS/nixpkgs/9b696460ac78b5ccfc17c854d8c976f20456e943";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Release-pinned home-manager matching arachnet's nixpkgs (26.05). Used
    # by the agent standalone homeConfiguration and by the optional NixOS
    # modules (inogai-arachnet / agent-arachnet).
    home-manager-release = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs-release";
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
  # there (so they are in scope for `mkHome`) and re-exported as a flake
  # output for inspection: `nix eval .#presets`.
  # ---------------------------------------------------------------------------

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-release,
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
      #   nix build .#homeConfigurations.arachnet.activationPackage   # arachnet (inogai)
      #   nix build .#homeConfigurations.agent.activationPackage      # arachnet (agent)
      #
      # Or with home-manager's standalone CLI:
      #
      #   home-manager switch --flake .#inogai      # mac
      #   home-manager switch --flake .#alexlychen  # windows (WSL)
      #   home-manager switch --flake .#agent -b hm-bak   # arachnet agent
      #
      # Agent on arachnet is standalone: `home-manager switch --flake .#agent`
      # (no nixos-rebuild). home-manager-path is one extra nix-profile
      # element beside nix-tool-install; do not put ad-hoc tools in
      # home.packages (name collision with `nix profile add`).
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
        agent = {
          system = "x86_64-linux";
          preset = "agent";
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
        ./modules/clipboard
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
        ./modules/pi

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
        {
          hm,
          pkgsFlake,
          p,
        }:
        let
          pkgs = pkgsFlake.legacyPackages.${p.system}.extend (
            nixpkgs.lib.composeManyExtensions overlays
          );
        in
        hm.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = sharedModules;
          extraSpecialArgs = {
            inherit nix-colors;
            preset = p.preset;
            yaziFlavors = nix-yazi-flavors.packages.${p.system};
          };
        };

      # NixOS module for one home-manager user on arachnet. useGlobalPkgs
      # stays off (default) so the neovim overlay can live at the per-user
      # nixpkgs.overlays — home-manager forbids nixpkgs.* options when
      # useGlobalPkgs is true. useUserPackages puts home.path in
      # /etc/profiles/per-user/<name>, not ~/.nix-profile.
      mkNixosHmUser =
        {
          username,
          presetName,
        }:
        {
          ...
        }:
        {
          imports = [ home-manager-release.nixosModules.home-manager ];

          home-manager = {
            useUserPackages = true;
            # Stock nushell stubs already exist in the agent home; backup
            # rather than fail activation. Standalone CLI uses `-b` instead.
            backupFileExtension = "hm-bak";
            extraSpecialArgs = {
              inherit nix-colors;
              preset = presetName;
              yaziFlavors = nix-yazi-flavors.packages.x86_64-linux;
            };
            users.${username} = {
              imports = sharedModules;
              nixpkgs.overlays = overlays;
            };
          };
        };
    in
    {
      homeConfigurations."inogai" = mkHome {
        hm = home-manager;
        pkgsFlake = nixpkgs;
        p = presets.mac;
      };
      homeConfigurations."alexlychen" = mkHome {
        hm = home-manager;
        pkgsFlake = nixpkgs;
        p = presets.windows;
      };
      homeConfigurations."arachnet" = mkHome {
        hm = home-manager-release;
        pkgsFlake = nixpkgs-release;
        p = presets.arachnet;
      };
      # Agent: HM 26.05 + arachnet nixpkgs pin so switch reuses the machine
      # store. Activate with:
      #   nix run github:nix-community/home-manager/release-26.05 -- switch --flake .#agent -b hm-bak
      homeConfigurations."agent" = mkHome {
        hm = home-manager-release;
        pkgsFlake = nixpkgs-release;
        p = presets.agent;
      };

      # arachnet as NixOS modules: imported by nixos-config so
      # `nixos-rebuild switch` activates home-manager along with the system
      # (no separate `home-manager switch` on the server).
      # home-manager-release (release-26.05) matches the consumer's nixpkgs
      # pin.
      nixosModules = {
        inogai-arachnet = mkNixosHmUser {
          username = "inogai";
          presetName = "arachnet";
        };
        agent-arachnet = mkNixosHmUser {
          username = "agent";
          presetName = "agent";
        };
        default = self.nixosModules.inogai-arachnet;
      };

      # Re-export presets for inspection (`nix eval .#presets`).
      inherit presets;
    };
}
