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
    # One nixpkgs for every machine, on arachnet's channel, so the homes
    # there reuse the system store.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # `nixpkgs-old` and `nixpkgs-unstable` carry one package each, both
    # pinned because the main nixpkgs cannot serve them: 26.05 would build
    # qutebrowser's QtWebEngine from source on darwin (no aarch64 cache), and
    # it has no `handy` at all.
    nixpkgs-old.url = "github:nixos/nixpkgs/release-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
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

  outputs =
    {
      nixpkgs,
      home-manager,
      nur,
      nvim-inogai,
      sbar-inogai,
      nix-yazi-flavors,
      nix-ai-tools,
      nix-colors,
      ...
    }@inputs:
    let
      # Shared module list. Mac-only modules are safe to import everywhere
      # because they are all guarded by `mkEnableOption` + `mkIf` and only
      # enabled from the machines that need them.
      sharedModules = [
        nix-colors.homeManagerModules.default
        nvim-inogai.homeModules.default
        ./modules/aerospace
        ./modules/cli-utils
        ./modules/direnv
        ./modules/fonts
        ./modules/fzfmenu
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
          handy = inputs.nixpkgs-unstable.legacyPackages.${final.system}.handy;
        })
      ];

      # The arguments every machine's home shares. Only `system` varies, so
      # generate one set per system; each home adds its own module from
      # ./machines on top. Build or switch a machine with:
      #
      #   nix build .#homeConfigurations.inogai.activationPackage     # mac
      #   nix build .#homeConfigurations.alexlychen.activationPackage # windows
      #
      #   home-manager switch --flake .#inogai      # mac
      #   home-manager switch --flake .#alexlychen  # windows (WSL)
      homeArgs = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ] (system: {
        pkgs = nixpkgs.legacyPackages.${system}.extend (nixpkgs.lib.composeManyExtensions overlays);
        extraSpecialArgs = {
          inherit nix-colors;
          yaziFlavors = nix-yazi-flavors.packages.${system};
        };
      });
    in
    {
      homeConfigurations."inogai" = home-manager.lib.homeManagerConfiguration (
        homeArgs.aarch64-darwin // { modules = sharedModules ++ [ ./machines/inogai.nix ]; }
      );
      homeConfigurations."alexlychen" = home-manager.lib.homeManagerConfiguration (
        homeArgs.x86_64-linux // { modules = sharedModules ++ [ ./machines/alexlychen.nix ]; }
      );
    };
}
