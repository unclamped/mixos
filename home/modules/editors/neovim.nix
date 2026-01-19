{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      # Theme (stylix will configure colors)
      vim-airline
      vim-airline-themes
      
      # File explorer
      nerdtree
      
      # Fuzzy finder
      fzf-vim
      
      # Git integration
      vim-fugitive
      vim-gitgutter
      
      # Language support
      vim-nix
      
      # Auto pairs
      auto-pairs
      
      # Commenting
      vim-commentary
    ];
    
    extraConfig = ''
      " Basic settings
      set number
      set relativenumber
      set tabstop=2
      set shiftwidth=2
      set expandtab
      set smartindent
      set mouse=a
      set clipboard=unnamedplus
      set ignorecase
      set smartcase
      set incsearch
      set hlsearch
      
      " Leader key
      let mapleader = " "
      
      " NERDTree
      nnoremap <leader>e :NERDTreeToggle<CR>
      
      " Clear search highlight
      nnoremap <leader>h :noh<CR>
      
      " Save and quit shortcuts
      nnoremap <leader>w :w<CR>
      nnoremap <leader>q :q<CR>
      
      " Split navigation
      nnoremap <C-h> <C-w>h
      nnoremap <C-j> <C-w>j
      nnoremap <C-k> <C-w>k
      nnoremap <C-l> <C-w>l
    '';
  };
}
