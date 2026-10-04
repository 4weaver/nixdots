# paneru replaces AeroSpace on the mba, and AeroSpace stays installed

The mba ran AeroSpace with ten numbered workspaces and `alt-1`..`alt-0`. The user found the
`option`+number workspace keys awkward and wanted a horizontally-scrolling ("niri-like") strip
instead of numbered workspaces. paneru is that strip: one infinite row per display, extending
right, over macOS's native Spaces. Its architecture makes the old scheme unportable — there is
no "workspace N" command at all, so the numbered workspaces and their bindings disappear rather
than get remapped. `window focus east/west`, trackpad/scroll sliding, and the experimental
virtual-workspace rows are the replacements.

paneru ships its own flake with a Home Manager module (`homeModules.paneru`) and package, so
nothing is packaged here. The flake adds the `paneru` input (following our nixpkgs) and imports
`paneru.homeModules.paneru` into the shared module list; `machines/inogai.nix` sets
`services.paneru.enable`, mirroring how `sbar-inogai` is wired. AeroSpace's toggle is set to
`false` and its module is left in the tree, dormant: AeroSpace is the fallback until the user
has lived with paneru, and flipping one line restores it. The WM layer of the ZMK keymap (layer
9, `Alt`-chords for AeroSpace) has no trigger key and is a separate ticket; it becomes dead but
is not touched here.

paneru is configured from `init.lua` (`services.paneru.config`), never from `settings`, because
an `init.lua` replaces the TOML entirely — setting both would silently drop the TOML half. The
script path depends on `xdg.enable`, which this repo leaves at its default `false`, so the
upstream module writes `~/.paneru.lua`; no `paneru.toml` exists in any discovery location, so
the script is the only configuration paneru can find. The `bindings` sub-table's keys are
space-separated argv (`["window focus west"]`), not the TOML underscore spelling: they desugar
onto `paneru.bind`, whose command strings are split on whitespace before the argv parser sees
them.

Every chord is held on the right hand. The keyboard tabs Alt on `L` and Shift on `K`, so
`L`+key is `alt - key` and `L K`+key is `alt + shift - key`. No prefix layer and no Hyper:
paneru is stateless (AeroSpace's `mode` has no equivalent), so a prefix could only live in ZMK,
and the mod-tap already gives the held-"WM mode" feel with no firmware change. The layout is a
plain axis map — `h`/`l` and `k`/`j` are west/east and north/south, and shift on those four
moves the window instead of the focus — on top of which three keys are pair-valued:

| chord | action |
| --- | --- |
| `h` / `l` | focus west / east along the strip |
| `k` / `j` | focus north / south down the stack (at a column's edge, native focus moves to the display in that direction) |
| shift + `h` / `l` | move window west / east |
| shift + `k` / `j` | move window north / south |
| `.` / shift + `.` | virtual row down / up (no wrap: no-op at row 2 / row 1) |
| `;` / shift + `;` | cursor to next display / window to next display |
| `m` / shift + `m` | stack onto the left column / unstack |
| `b` / shift + `b` | column width − / + |
| `u` | fzfmenu launcher |
| `y` | float / unfloat the focused window |
| shift + `i` | close the focused window |
| `i` | unbound |

Plain `i` is deliberately unbound, and `window virtualmove` (move the focused window to the
other row) has no key: a pair-valued key only carries a forward and a reverse direction, the
rows' reverse slot went to `.`, and the freed `;` went to the display pair.

## Considered Options

- **Package paneru into `nur-packages` and wire a home module by hand.** Rejected: upstream
  already ships both, the same shape as `sbar-inogai`, so there is no packaging to own.
- **Use `darwinModules.paneru`.** Rejected: it exists, but its docs say to pick one of the two,
  and this flake builds a home, not a darwin system.
- **Set `settings` (TOML) and `config` (Lua) together.** Rejected: the `init.lua` would win and
  the TOML would be dead weight that reads as if it were live.
- **Recreate ten numbered workspaces as virtual-workspace rows.** Rejected: that is the
  complaint being fixed, and rows are not the same object — they collapse when their last
  window leaves, and there is no directional `focus` analogue for jumping straight to row N;
  `window virtualnum <n>` exists but the final key set stays directional.
- **Keep feeding sketchybar's workspace block.** Rejected for this pass: paneru has no
  `exec-on-workspace-change`, and the user deferred the sketchybar migration. The block is left
  in place (so nothing is silently deleted) and documented as stale; paneru's own menu bar
  indicator covers the need meanwhile.
- **A tmux-style prefix (Hyper + a key) or a Hyper chord set.** Rejected: Hyper already
  contains Shift, so a Hyper+Shift sub-layer is indistinguishable from plain Hyper, and paneru
  cannot hold a mode anyway. Alt mod-tap already gives the same feel.

## Consequences

- Remote `alt-1`..`alt-0`, `persistent-workspaces`, `workspace-to-monitor-force-assignment`,
  AeroSpace's `mode` blocks and its `on-window-detected` rules have no equivalent; the
  float rule for the fzfmenu launcher moved to a paneru `[windows]` rule.
- Close (`alt + shift - i`) has no paneru command; it is a Lua binding that presses the focused
  window's close button (`AXPress` on its `AXCloseButton`) through System Events, which needs
  Automation permission on top of Accessibility. A synthetic ⌘W does not work: the binding's own
  physical alt+shift are still held when the event is posted, so the target app sees ⌘⌥⇧W and
  ignores it. Paneru notifies on failure rather than failing silently. macOS only attributes the
  Apple event to Paneru when the daemon's process image is an application bundle's own Mach-O:
  the nix bash the launchd agent wraps resolves to no bundle, so Automation showed no Paneru row
  and the request was denied without a prompt. `modules/paneru` therefore builds a `Paneru.app`
  (adhoc-signed, `NSAppleEventsUsageDescription`, `CFBundleIdentifier
  com.github.karinushka.paneru`) and points the launchd agent at
  `Paneru.app/Contents/MacOS/paneru`. A `CFBundleExecutable` that is a script or a symlink does
  not work — both still resolve to the interpreter.
- The display pair sits on `;` (`mouse nextdisplay`) and shift-`;` (`window nextdisplay`),
  which the dropped virtual-row bindings freed.
- `window_resize_cycle` is off: `b`/`shift-b` are an explicit width pair, and wrapping from the
  widest preset back to the narrowest would read as a bug.
- Two virtual rows, fixed (`default_workspaces = 2`,
  `create_virtual_workspace_automatically = false`), so the row pair on `.`/shift-`.` is
  bounded and cannot grow a third row. Rows do not wrap: `window virtual south` (`/east`) at
  the last row stays put unless auto-create is on, and `window virtual north` (`/west`) is
  `saturating_sub`, so `.` is a no-op on row 2 and shift-`.` is a no-op on row 1. Verified in
  `src/ecs/workspace.rs::switch_virtual_workspace_bind`; the option name is
  `create_virtual_workspace_automatically`, not the `create_workspace_automatically` accessor
  the source calls it.
- AeroSpace must not run alongside paneru — two window managers fighting over windows. Its
  launchd agent stops when the toggle is false; the app is quit by hand if it is still up.
- The launcher binding moved from AeroSpace's `exec-and-forget` to a `paneru.exec` Lua handler,
  since no binding string can express a program launch.
