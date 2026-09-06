{
  config,
  lib,
  ...
}:
let
  cfg = config.my.modules.qutebrowser;
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

          # qwerty
          h = "scroll-px 0 100";
          j = "scroll-px 0 -100";
          k = "scroll-px -100 0";
          l = "scroll-px 100 0";
          H = "back";
          L = "forward";
          J = "tab-next";
          K = "tab-prev";

          i = "mode-enter insert";
        };
      };
    };
  };
}
