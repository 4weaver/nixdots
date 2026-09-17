{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.cli-utils;

  fzfOptions = [
    "--prompt=❯"
    "--gutter=' ' "
    "--color=bg:-1,bg+:-1"
    "--color=hl:#d8a657,hl+:#d8a657:reverse"
    "--color=fg:#ebdbb2,fg+:#ebdbb2:reverse"
    "--color=header:#83a598"
    "--color=spinner:#8ec07c"
    "--color=marker:#8ec07c,header:#83a598"
    "--color=prompt:#89b482,pointer:#83a598"
    "--color=info:#a89984,separator:#a89984"
    "--color=query:#ebdbb2:regular"
  ];
in
{
  options.my.modules.cli-utils.enable = lib.mkEnableOption "essential CLI utilities";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # --- Core / file operations ---
      coreutils
      findutils
      diffutils
      file
      which
      gnutar
      p7zip
      zstd
      gzip
      xz
      unzip
      zip
      trash-cli

      # --- Networking ---
      curl
      wget
      dig
      httpie
      openssh

      # --- Search / filter / view ---
      ripgrep
      fd
      jq
      yq-go
      less
      bat
      tree
      delta

      # --- Data / text processing ---
      gnused
      gawk
      bc
      perl
      python3

      # --- System / process inspection ---
      util-linux
      lsof
      htop
      btop

      # --- Security / crypto ---
      gnupg
      age
      openssl

      # --- VCS ---
      git
      github-cli
      git-lfs
      lazygit

      # --- Nix ---
      nix-prefetch-git
      nixpkgs-fmt
      nvd
      nix-output-monitor

      # --- macOS platform helpers ---
      noti

      # --- Themed wrappers ---
      (writeShellScriptBin "fzf" ''
        export FZF_DEFAULT_OPTS="${lib.concatStringsSep " " fzfOptions}"
        exec ${pkgs.fzf}/bin/fzf "$@"
      '')
    ];

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        AddKeysToAgent = "12h";
      };
      # Host list for the fzfmenu ssh plugin (modules/fzfmenu).
      settings."arachnet" = {
        HostName = "192.168.70.100";
        User = "agent";
      };
      # `cockpit` (from the zide flake, installed in the agent profile) drops
      # straight into the arachnet session with its dir, layout and editor env.
      settings."cockpit" = {
        HostName = "192.168.70.100";
        User = "agent";
        RequestTTY = "force";
        RemoteCommand = "cockpit";
      };
    };

    services.ssh-agent = {
      enable = true;
      defaultMaximumIdentityLifetime = 3600;
    };

    programs.ripgrep-all = {
      enable = true;
    };
  };
}
