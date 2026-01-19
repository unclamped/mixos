{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    # Oh-My-Zsh
    oh-my-zsh = {
      enable = true;
      plugins = [ 
        "git" 
        "sudo" 
        "docker" 
        "kubectl"
      ];
    };
    
    # Aliases
    shellAliases = {
      # NixOS shortcuts
      nrs = "sudo nixos-rebuild switch --flake ~/.dotfiles#main";
      nrb = "sudo nixos-rebuild boot --flake ~/.dotfiles#main";
      nrt = "sudo nixos-rebuild test --flake ~/.dotfiles#main";
      
      # Update flake
      update = "cd ~/.dotfiles && nix flake update && nrs";
      
      # Common
      ll = "ls -lah";
      la = "ls -A";
      l = "ls -CF";
      
      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline";
      
      # CD shortcuts
      ".." = "cd ..";
      "..." = "cd ../..";
      
      # Trash instead of rm (safer)
      rm = "trash";
    };
    
    # Init extra
    initExtra = ''
      # Custom prompt
      autoload -U colors && colors
      
      # History settings
      HISTSIZE=10000
      SAVEHIST=10000
      setopt HIST_IGNORE_ALL_DUPS
      setopt HIST_FIND_NO_DUPS
      setopt HIST_SAVE_NO_DUPS
      
      # Case-insensitive completion
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
    '';
  };
  
  # Starship prompt
  programs.starship = {
    enable = true;
    
    settings = {
      add_newline = true;
      
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
      
      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };
      
      git_branch = {
        symbol = " ";
      };
      
      git_status = {
        conflicted = "🏳";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "🤷";
        stashed = "📦";
        modified = "📝";
        staged = "[++($count)](green)";
        renamed = "👅";
        deleted = "🗑";
      };
      
      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state]($style) ";
      };
    };
  };
  
  # direnv for automatic nix-shell
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  
  # fzf fuzzy finder
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  
  # eza (modern ls replacement)
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = true;
  };
  
  # bat (better cat)
  programs.bat = {
    enable = true;
  };
}
