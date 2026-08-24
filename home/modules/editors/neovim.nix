{ config, pkgs, ... }:

let
  # codelldb ships inside the vscode-lldb extension; rustaceanvim wires it up
  # for DAP debugging of `debuggables`/`testables`.
  codelldb = pkgs.vscode-extensions.vadimcn.vscode-lldb;
  codelldbPath = "${codelldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  liblldbPath = "${codelldb}/share/vscode/extensions/vadimcn.vscode-lldb/lldb/lib/liblldb.so";
  # Standard-library source so rust-analyzer can resolve `go-to-definition`
  # into std/core/alloc (nix's rustc sysroot ships without the source tree).
  rustLibSrc = "${pkgs.rustPlatform.rustLibSrc}";
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # Tools rust-analyzer / cargo need on nvim's runtime PATH so the editor is
    # self-sufficient for Rust without relying on a project dev-shell.
    extraPackages = with pkgs; [
      rust-analyzer
      cargo
      rustc
      clippy
      rustfmt
      gcc # linker for `cargo build` / proc-macro expansion
    ];

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

      # ── Rust ──────────────────────────────────────────────────────────
      # rustaceanvim manages rust-analyzer, inlay hints, code actions,
      # runnables/debuggables and macro expansion. It configures itself via
      # vim.g.rustaceanvim — do NOT call a setup() function on it.
      rustaceanvim
      # Cargo.toml: inline crate versions, updates, features, completions.
      crates-nvim

      # Treesitter parsers (nixpkgs ships the "main" rewrite — highlighting is
      # driven by Neovim's built-in vim.treesitter.start() below, not the old
      # configs.setup API). Grammars land on the runtimepath here.
      (nvim-treesitter.withPlugins (p: [ p.rust p.toml p.nix ]))

      # ── Completion ────────────────────────────────────────────────────
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip

      # ── Debugging (DAP) ───────────────────────────────────────────────
      nvim-dap
      nvim-dap-ui
      nvim-nio

      # Icons for the completion menu / dap-ui
      nvim-web-devicons
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
      set signcolumn=yes
      set updatetime=300
      set completeopt=menu,menuone,noselect

      " Rust files use 4-space indentation (rustfmt convention)
      autocmd FileType rust setlocal tabstop=4 shiftwidth=4

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

    # Modern Rust/LSP/completion/debug setup lives in Lua.
    extraLuaConfig = ''
      -- ── Treesitter highlighting (main-branch: use built-in starter) ──────
      vim.api.nvim_create_autocmd('FileType', {
        pattern = { 'rust', 'toml', 'nix' },
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })

      -- ── Diagnostics UI ───────────────────────────────────────────────────
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = { border = 'rounded', source = true },
      })

      -- ── Completion (nvim-cmp) ────────────────────────────────────────────
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>']     = cmp.mapping.abort(),
          ['<CR>']      = cmp.mapping.confirm({ select = true }),
          ['<C-b>']     = cmp.mapping.scroll_docs(-4),
          ['<C-f>']     = cmp.mapping.scroll_docs(4),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, {
          { name = 'buffer' },
          { name = 'path' },
        }),
      })

      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- ── Cargo.toml helper (crates.nvim) ──────────────────────────────────
      -- Uses crates.nvim's in-process language server so completions, hover
      -- and code actions on Cargo.toml flow through the normal LSP path
      -- (the deprecated nvim-cmp source is intentionally not used).
      require('crates').setup({
        lsp = {
          enabled = true,
          actions = true,
          completion = true,
          hover = true,
        },
      })

      -- ── DAP (debugging) UI wiring ────────────────────────────────────────
      local dap = require('dap')
      local dapui = require('dapui')
      dapui.setup()
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

      vim.keymap.set('n', '<leader>db', dap.toggle_breakpoint, { desc = 'DAP: breakpoint' })
      vim.keymap.set('n', '<leader>dc', dap.continue,          { desc = 'DAP: continue' })
      vim.keymap.set('n', '<leader>di', dap.step_into,         { desc = 'DAP: step into' })
      vim.keymap.set('n', '<leader>do', dap.step_over,         { desc = 'DAP: step over' })
      vim.keymap.set('n', '<leader>du', dapui.toggle,          { desc = 'DAP: toggle UI' })

      -- ── Shared LSP keymaps (buffer-local, set on attach) ─────────────────
      local function lsp_keymaps(bufnr)
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
        end
        map('n', 'gd', vim.lsp.buf.definition,      'LSP: definition')
        map('n', 'gD', vim.lsp.buf.declaration,     'LSP: declaration')
        map('n', 'gi', vim.lsp.buf.implementation,  'LSP: implementation')
        map('n', 'gy', vim.lsp.buf.type_definition, 'LSP: type definition')
        map('n', 'gr', vim.lsp.buf.references,      'LSP: references')
        map('n', 'K',  vim.lsp.buf.hover,           'LSP: hover')
        map('n', '<leader>rn', vim.lsp.buf.rename,      'LSP: rename')
        map('n', '<leader>ca', vim.lsp.buf.code_action, 'LSP: code action')
        map('n', '<leader>ff', function() vim.lsp.buf.format({ async = true }) end, 'LSP: format')
        map('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, 'Diag: prev')
        map('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end,  'Diag: next')
        map('n', '<leader>ld', vim.diagnostic.open_float, 'Diag: line float')
      end

      -- ── Rust: rustaceanvim ───────────────────────────────────────────────
      vim.g.rustaceanvim = {
        tools = {
          float_win_config = { border = 'rounded' },
        },
        server = {
          capabilities = capabilities,
          on_attach = function(client, bufnr)
            lsp_keymaps(bufnr)

            -- rustaceanvim-flavored overrides (richer than the generic LSP ones)
            local function rmap(lhs, action, desc)
              vim.keymap.set('n', lhs, function() vim.cmd.RustLsp(action) end,
                { buffer = bufnr, silent = true, desc = desc })
            end
            vim.keymap.set('n', 'K', function() vim.cmd.RustLsp({ 'hover', 'actions' }) end,
              { buffer = bufnr, silent = true, desc = 'Rust: hover actions' })
            vim.keymap.set('n', '<leader>ca', function() vim.cmd.RustLsp('codeAction') end,
              { buffer = bufnr, silent = true, desc = 'Rust: code action' })
            rmap('<leader>rr', 'runnables',    'Rust: runnables')
            rmap('<leader>rd', 'debuggables',  'Rust: debuggables')
            rmap('<leader>rt', 'testables',    'Rust: testables')
            rmap('<leader>rm', 'expandMacro',  'Rust: expand macro')
            rmap('<leader>rc', 'openCargo',    'Rust: open Cargo.toml')
            rmap('<leader>rp', 'parentModule', 'Rust: parent module')

            -- Inlay hints (types, parameter names, chaining)
            if client.server_capabilities.inlayHintProvider then
              vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
            end
          end,
          default_settings = {
            ['rust-analyzer'] = {
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
                buildScripts = { enable = true },
                -- point rust-analyzer at the std source shipped by nix
                sysrootSrc = '${rustLibSrc}',
              },
              -- lint with clippy on save
              checkOnSave = true,
              check = { command = 'clippy' },
              procMacro = { enable = true },
              inlayHints = {
                bindingModeHints = { enable = true },
                closureReturnTypeHints = { enable = 'always' },
                lifetimeElisionHints = { enable = 'skip_trivial' },
              },
            },
          },
        },
        -- DAP: use the codelldb bundled with the vscode-lldb extension (nix path)
        dap = {
          adapter = require('rustaceanvim.config').get_codelldb_adapter(
            '${codelldbPath}',
            '${liblldbPath}'
          ),
        },
      }

      -- Fallback for std navigation on older rust-analyzer paths
      vim.env.RUST_SRC_PATH = '${rustLibSrc}'

      -- Format Rust on save (rustfmt via rust-analyzer)
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = '*.rs',
        callback = function() vim.lsp.buf.format({ async = false }) end,
      })
    '';
  };
}
