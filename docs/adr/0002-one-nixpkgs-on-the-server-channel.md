# One nixpkgs, on the server's channel, with pins for what it cannot serve

This flake tracked the flakehub weekly with home-manager master, while arachnet and its nixos-config track the `nixos-26.05` channel. A home built here therefore pulled a second copy of nixpkgs instead of reusing the store the machine already had, and the two home-managers sat on either side of the channel boundary.

The main `nixpkgs` is now `nixos-26.05` and `home-manager` is the matching `release-26.05`, for every machine including the mac. Two extra inputs are pinned to carry one package each, because the main nixpkgs cannot serve them:

- `qutebrowser` from `release-25.11` — 26.05 has it, but aarch64-darwin has no binary cache for its QtWebEngine, so switching would turn into a source build.
- `handy` from `nixpkgs-unstable` — 26.05 has no `handy` at all; it reached unstable after the branch point and was never backported.

## Consequences

The mac moves off the weekly onto a release channel, so its next switch is a large rebuild, and its package set now lags unstable by design. Two of the three nixpkgs inputs exist for a single package each; their reasons are recorded beside the pins in `flake.nix`. The `qutebrowser` pin predates this and its reason was recorded nowhere — recovering it took a binary-cache check, which is why they are written down now.
