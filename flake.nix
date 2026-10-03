{
  description = "Home Manager configuration";

  nixConfig = {
    extra-substituters = [
      "https://inogai.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "inogai.cachix.org-1:gJVZ8+i50F4/I9/TBnkpBlAGzqzpJQdtK/iQATuWY60="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    # Every machine shares one nixpkgs. Track unstable, not the release
    # branch: the llm-agents packages the homes pull in (`pi`, `omp`) are
    # built by llm-agents CI against nixpkgs-unstable, so a release-branch
    # nixpkgs puts their outputs off the binary cache and they compile here.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # `nixpkgs-old` carries the one package the main nixpkgs cannot serve:
    # `qutebrowser` — 26.05+ builds its QtWebEngine from source on darwin (no
    # aarch64 cache), so it stays on release-25.11 where the cache has it.
    nixpkgs-old.url = "github:nixos/nixpkgs/release-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/master";
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
    # llm-agents CI builds `pi`/`omp` against its own nixpkgs, which is
    # nixpkgs-unstable. Following the main input keeps that alignment without
    # anyone editing the lock by hand — which is what commit d95fc36 did, and
    # it moved every llm-agents output off cache.numtide.com.
    nix-ai-tools = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
        ./modules/herdr
        ./modules/jankyborders
        ./modules/kitty
        ./modules/pikpak
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

      # The arguments every machine's home shares. Only `system` varies, so
      # generate one set per system; each home adds its own module from
      # ./machines on top. Build or switch a machine with:
      #
      #   nix build .#homeConfigurations.inogai.activationPackage     # mac
      #   nix build .#homeConfigurations.alexlychen.activationPackage # windows
      #   nix build .#homeConfigurations.agent.activationPackage      # arachnet (agent)
      #
      #   home-manager switch --flake .#inogai      # mac
      #   home-manager switch --flake .#alexlychen  # windows (WSL)
      #   home-manager switch --flake .#agent       # arachnet (agent)
      #
      # The agent home is standalone — no nixos-rebuild, home changes must
      # not rebuild the OS — and needs `-b hm-bak`, since it already has
      # stock nushell stubs.
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
      homeConfigurations."agent" = home-manager.lib.homeManagerConfiguration (
        homeArgs.x86_64-linux // { modules = sharedModules ++ [ ./machines/agent.nix ]; }
      );
    };
}
