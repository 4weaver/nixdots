{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.pikpak;

  # PikPak ships only a prebuilt binary; nixpkgs has no package for it. The
  # release is ad-hoc signed by upstream, which is enough to run on Apple
  # silicon, and it is fetched straight from download.mypikpak.com into the
  # store — the nix sandbox re-codesign is not needed because the file is
  # installed verbatim, never rewritten.
  #
  # Bump `version` and `hash` from https://download.mypikpak.com/cli/release/.
  # `hash` is upstream's own SHA-256 of the binary (the value the official
  # Homebrew tap `pikcloud/tap/pikpak-cli` also pins).
  #
  # `stdenvNoCC` keeps it to a fetch-and-install with no compiler needed.
  version = "0.5.2";

  src = pkgs.fetchurl {
    url = "https://download.mypikpak.com/cli/release/v${version}/pikpak_darwin_arm64";
    hash = "sha256-MG4c+2sSg0s2xKOHq17oEOVg29Z6Pojo8AuGHeo992U=";
  };

  pikpak-unwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "pikpak-cli";
    inherit version src;

    # The release is a bare Mach-O executable with no extension.
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/pikpak"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Cloud storage command-line tool for PikPak";
      homepage = "https://mypikpak.com";
      license = licenses.unfree;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "pikpak";
    };
  };
in
{
  options.my.modules.pikpak.enable = lib.mkEnableOption "PikPak cloud storage CLI";

  config = lib.mkIf cfg.enable {
    home.packages = [ pikpak-unwrapped ];
  };
}
