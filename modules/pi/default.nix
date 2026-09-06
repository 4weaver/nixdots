{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.my.modules.pi.enable = lib.mkEnableOption "pi coding agent";

  config = lib.mkIf config.my.modules.pi.enable {
    # Only install the pi binary. All ~/.pi/agent config (settings.json,
    # models.json, extensions, skills) is managed as a live git repo at
    # ~/.pi with git-crypt for secrets. See github.com/inogai/pi-config.
    # Nothing under ~/.pi is declared here, so pi can rewrite its own
    # settings.json at runtime without fighting home-manager symlinks.
    #
    # git-crypt is co-installed here because git's clean/smudge filters
    # (configured by `git-crypt init` into .git/config) invoke `git-crypt`
    # as a bare command on every add/checkout in ~/.pi. It must be on PATH
    # at arbitrary moments, so a real package install is required rather
    # than `nix run`.
    home.packages = [
      pkgs.nix-ai-tools.pi
      pkgs.git-crypt
    ];
  };
}
