{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:

# nixpkgs builds CopyQ for Linux only; upstream ships a signed arm64 .dmg.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "copyq";
  version = "16.0.0";

  src = fetchurl {
    url = "https://github.com/hluk/CopyQ/releases/download/v${finalAttrs.version}/CopyQ-${finalAttrs.version}-macos-12-m1.dmg";
    hash = "sha256-V1Y/ssokdRl0w1t0TKfqLFwXG8XAD1mzyDeZEodq5LE=";
  };

  nativeBuildInputs = [ undmg ];

  # undmg unpacks into $PWD; otherwise the .app is auto-detected as sourceRoot.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications $out/bin
    cp -R CopyQ.app $out/Applications/

    # The .dmg is only linker-signed and the embedded Qt frameworks fail even
    # that check at exec (SIGKILL on the first invalid page). Re-sign the bundle
    # ad-hoc: same bytes, validly signed. codesign rewrites the Mach-O files in
    # place, hence the writable bit.
    chmod -R u+w $out/Applications/CopyQ.app
    /usr/bin/codesign --force --deep --sign - $out/Applications/CopyQ.app

    # A wrapper, not a symlink: CopyQ resolves its plugins relative to the
    # executable's path, and macOS reports a symlink's directory rather than the
    # bundle's — with a plain link the server starts with no plugins at all.
    cat > $out/bin/copyq <<WRAP
#!/bin/sh
exec $out/Applications/CopyQ.app/Contents/MacOS/CopyQ "\$@"
WRAP
    chmod +x $out/bin/copyq

    runHook postInstall
  '';

  meta = {
    description = "Clipboard manager with advanced features (prebuilt macOS bundle)";
    homepage = "https://hluk.github.io/CopyQ";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.darwin;
    mainProgram = "copyq";
  };
})
