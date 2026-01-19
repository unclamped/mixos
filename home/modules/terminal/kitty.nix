{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;
    
    # Stylix will handle colors automatically
    # But you can override specific settings
    
    settings = {
      # Font (Stylix sets this, but you can override)
      # font_family = "JetBrainsMono Nerd Font";
      # font_size = 12;
      
      # Performance
      sync_to_monitor = true;
      
      # Cursor
      cursor_shape = "block";
      cursor_blink_interval = 0;
      
      # Scrollback
      scrollback_lines = 10000;
      
      # Mouse
      mouse_hide_wait = 3;
      
      # Window
      window_padding_width = 10;
      hide_window_decorations = true;
      confirm_os_window_close = 0;
      
      # Tab bar
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      
      # Opacity
      background_opacity = "0.95";
      
      # Shell
      shell = "zsh";
    };
    
    # Keybindings
    keybindings = {
      # Tabs
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+q" = "close_tab";
      "ctrl+shift+right" = "next_tab";
      "ctrl+shift+left" = "previous_tab";
      
      # Windows
      "ctrl+shift+enter" = "new_window";
      "ctrl+shift+w" = "close_window";
      
      # Scrolling
      "ctrl+shift+k" = "scroll_line_up";
      "ctrl+shift+j" = "scroll_line_down";
      "ctrl+shift+page_up" = "scroll_page_up";
      "ctrl+shift+page_down" = "scroll_page_down";
      "ctrl+shift+home" = "scroll_home";
      "ctrl+shift+end" = "scroll_end";
      
      # Font size
      "ctrl+shift+equal" = "increase_font_size";
      "ctrl+shift+minus" = "decrease_font_size";
      "ctrl+shift+backspace" = "restore_font_size";
      
      # Copy/paste
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
    };
  };
}
