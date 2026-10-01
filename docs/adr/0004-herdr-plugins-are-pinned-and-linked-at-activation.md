# The herdr-quicklook plugin is pinned in Nix and linked at activation

herdr keeps its plugin list in `~/.config/herdr/plugins.json`, an imperative registry that the
TUI itself rewrites when a plugin is toggled; there is no config.toml key that declares plugins
(herdrdev/herdr#762 is the open request). The plugin was therefore installed by hand
(`herdr plugin install dwarvesf/herdr-quicklook`) plus a local 10-line patch to
`scripts/lib.sh`, and nothing in this repo could rebuild that state — the other two homes had
no plugin at all.

Two seams were possible. A managed `plugins.json` was rejected: herdr rewrites the file on
every enable/disable, so a home-manager-owned copy fights the TUI and the next toggle wins.
The seam used instead is a two-part split — Nix pins the plugin as a derivation, and a
`home.activation` hook registers the pinned directory with `herdr plugin link <store-path>`.

`plugin link` accepts a read-only directory, reports `source: local`, and upserts its registry
entry keyed by plugin id, so re-running it on every activation is safe and quietly repoints the
entry at the new store path after a rebuild. It also persists while no herdr server is running,
which is what lets a home activate on a machine where herdr is not up.

The patch is carried as `modules/herdr/cjk-span-separator.patch` rather than as a local
checkout edit, so the pinned revision plus this file is the complete recipe. It treats a
non-ASCII run in pane text as a token separator: "文件在scripts/lib.sh里面" is one
whitespace-delimited word, and splitting on spaces alone hands the trim rules a span they
cannot rescue, so the path resolves to nothing.

## Considered Options

- **`herdr plugin install` in the activation script.** Rejected: it needs the network and a
  GitHub checkout at activation time, and it pins nothing — the revision would drift.
- **A `postPatch` sed instead of a patch file.** Rejected: the plugin's version moves; a
  context-free substitution would fail silently on the next bump instead of refusing to apply.
- **A managed `plugins.json`.** Rejected above: herdr rewrites it.

## Consequences

- `herdr plugin list` shows a `/nix/store/…` path, so the plugin is GC-managed and the
  imperatively installed checkout can be deleted.
- Both activation commands end in `|| true`, matching home-manager's own herdr module: a home
  must activate with no herdr server running.
- quicklook resolves its renderers by name through the herdr *server's* PATH, so the optional
  tools (and `jq`, which the plugin requires) ride in `home.packages` rather than in the
  plugin's own closure.
- Bumping the plugin means bumping `rev` + `hash` in `modules/herdr/herdr-quicklook.nix` and
  checking that the patch still applies.
