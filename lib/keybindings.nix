# Global keybinding configuration
# This file defines direction and mode keys used across applications
let
  # preset = "colemak-dh";
  preset = "qwerty";
  presets = {
    colemak-dh = {
      direction = {
        left = "m";
        down = "n";
        up = "e";
        right = "i";
      };
      mode = {
        insert = "l";
      };
    };
    qwerty = {
      direction = {
        left = "h";
        down = "j";
        up = "k";
        right = "l";
      };
      mode = {
        insert = "i";
      };
    };
  };
in
presets.${preset}
