{ config, lib, pkgs, ... }:
let
  cfg = config.my.modules.paneru;

  inherit (config.home) profileDirectory;

  # Read once: the launcher binding below interpolates it into a store path.
  paneruPackage = config.services.paneru.finalPackage;

  # macOS only attributes an Apple-Events request (the close handler's
  # `osascript` keystroke) to a bundle when the process image is that bundle's
  # own Mach-O. The launchd wrapper is nix bash, which resolves to no bundle,
  # so System Settings → Automation showed no "Paneru" row and the request was
  # denied with no prompt. `NSAppleEventsUsageDescription` is what makes macOS
  # ask instead. Verified against tccd: a bundle whose CFBundleExecutable is a
  # script or a symlink still resolves to the interpreter.
  appBundle = pkgs.runCommand "Paneru.app" { } ''
    mkdir -p $out/Contents/MacOS
    cp ${paneruPackage}/bin/.paneru-wrapped $out/Contents/MacOS/paneru
    chmod u+w $out/Contents/MacOS/paneru
    cp ${
      pkgs.writeText "Paneru-Info.plist" ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleDevelopmentRegion</key>
          <string>en</string>
          <key>CFBundleDisplayName</key>
          <string>Paneru</string>
          <key>CFBundleExecutable</key>
          <string>paneru</string>
          <key>CFBundleIdentifier</key>
          <string>com.github.karinushka.paneru</string>
          <key>CFBundleInfoDictionaryVersion</key>
          <string>6.0</string>
          <key>CFBundleName</key>
          <string>Paneru</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>LSMinimumSystemVersion</key>
          <string>12.0</string>
          <key>LSUIElement</key>
          <true/>
          <key>NSAppleEventsUsageDescription</key>
          <string>Paneru sends the close-window keystroke to the focused app.</string>
        </dict>
        </plist>
      ''
    } $out/Contents/Info.plist
    /usr/bin/codesign --force --sign - $out
  '';

  configLua = ''
    paneru.setup {
      options = {
        focus_follows_mouse = false,
        mouse_follows_focus = false,
        auto_center = true,
        -- Startup-only: a Space macOS creates later gets one row.
        default_workspaces = 2,
        window_resize_cycle = false,
      },

      padding = {
        top = 4,
        bottom = 4,
        left = 4,
        right = 4,
      },

      swipe = {
        gesture = {
          fingers_count = 4,
          vertical = false,
        },
        scroll = {
          window_step = true,
          vertical_modifier = "shift",
        },
      },

      windows = {
        -- 6+6 horizontal / 4+4 vertical = AeroSpace's 12/8 gap.
        all = {
          title = ".*",
          horizontal_padding = 6,
          vertical_padding = 4,
        },
        fzfmenu = {
          bundle_id = "net.kovidgoyal.kitty",
          title = "^fzfmenu$",
          floating = true,
        },
      },

      bindings = {
        ["window focus west"] = "alt - h",
        ["window focus east"] = "alt - l",
        ["window focus north"] = "alt - k",
        ["window focus south"] = "alt - j",

        ["window swap west"] = "alt + shift - h",
        ["window swap east"] = "alt + shift - l",
        ["window swap north"] = "alt + shift - k",
        ["window swap south"] = "alt + shift - j",

        -- Two fixed rows, no wrap: `.` at row 2 is a no-op (auto-create is off).
        ["window virtual south"] = "alt - period",
        ["window virtual north"] = "alt + shift - period",

        ["window shrink"] = "alt - b",
        ["window grow"] = "alt + shift - b",

        ["window stack"] = "alt - m",
        ["window unstack"] = "alt + shift - m",

        ["mouse nextdisplay"] = "alt - semicolon",
        ["window nextdisplay"] = "alt + shift - semicolon",

        ["window manage"] = "alt - y",
      },
    }

    paneru.bind("alt - u", function()
      paneru.exec("${profileDirectory}/bin/fzfmenu-launch")
    end)

    -- Paneru has no close verb. A synthetic ⌘W does not work: the physical
    -- alt+shift are still held when the event is posted, so the app sees
    -- ⌘⌥⇧W and ignores it. Press the close button over Accessibility instead,
    -- under the same Automation → System Events grant.
    paneru.bind("alt + shift - i", function()
      local result = paneru.exec("/usr/bin/osascript", {
        "-e",
        [[
tell application "System Events"
  perform action "AXPress" of (first button whose subrole is "AXCloseButton") of (front window of (first application process whose frontmost is true))
end tell
]],
      })
      if result.code ~= 0 then
        paneru.flash("close failed: " .. tostring(result.stderr))
      end
    end)
  '';
in
{
  options.my.modules.paneru.enable = lib.mkEnableOption "paneru scrolling window manager";

  config = lib.mkIf cfg.enable {
    services.paneru = {
      enable = true;
      config = configLua;
    };

    # Launch the bundle's Mach-O so TCC attributes the process to the bundle.
    # `Program` carries the upstream module's plain binary path; replace it.
    launchd.agents.paneru.config = {
      Program = lib.mkForce null;
      ProgramArguments = [ "${appBundle}/Contents/MacOS/paneru" ];
    };
  };
}
