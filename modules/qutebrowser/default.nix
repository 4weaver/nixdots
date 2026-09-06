{
  config,
  lib,
  ...
}:
let
  cfg = config.my.modules.qutebrowser;
  keys = import ../../lib/keybindings.nix;
  dir = keys.direction;
  mode = keys.mode;
in
{
  options.my.modules.qutebrowser.enable = lib.mkEnableOption "qutebrowser web browser";

  config = lib.mkIf cfg.enable {
    programs.qutebrowser = {
      enable = true;
      loadAutoconfig = true;
      searchEngines = {
        DEFAULT = "https://google.com/search?q={}";
        g = "https://google.com/search?q={}";
        p = "https://www.perplexity.ai/?q={}";
      };
      settings = {
        url.default_page = "https://www.google.com";
        colors.webpage.bg = "white";
        fonts.default_size = "18pt";
        tabs.position = "left";
        editor.command = [
          "kitty"
          "-e"
          "nvim"
          "-f"
          "{file}"
          "-c"
          "normal {line}G{column0}l"
        ];
      };
      keyBindings = {
        normal = {
          " e" = "config-cycle tabs.show always switching";
          "  " = "cmd-set-text -s :tab-select";
          "<F12>" = "devtools";
          "xx" = "config-source";
          "xr" = "greasemonkey-reload;; reload";
          "xc" = "spawn sh -c 'echo \"{url}\" >> $HOME/urls.txt'";

          ${dir.left} = "scroll-px 0 100";
          ${dir.down} = "scroll-px 0 -100";
          ${dir.up} = "scroll-px -100 0";
          ${dir.right} = "scroll-px 100 0";
          ${lib.toUpper dir.left} = "back";
          ${lib.toUpper dir.right} = "forward";
          ${lib.toUpper dir.down} = "tab-next";
          ${lib.toUpper dir.up} = "tab-prev";

          ${mode.insert} = "mode-enter insert";
        };
      };
    };
  };
}
