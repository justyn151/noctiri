vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.background = "dark"
vim.opt.termguicolors = true
vim.opt.guicursor = "a:ver25-blinkwait300-blinkon200-blinkoff150"
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.wrap = false
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.clipboard = "unnamedplus"
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hidden = true
vim.opt.updatetime = 300
vim.opt.signcolumn = "yes"

local map = vim.keymap.set
map("n", "<leader>n", function()
    vim.opt.number = not vim.opt.number:get()
    vim.opt.relativenumber = vim.opt.number:get()
end, { desc = "Toggle line numbers" })
map("n", "<leader><CR>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "n", "nzz", { desc = "Next search result" })
map("n", "N", "Nzz", { desc = "Previous search result" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Close window" })
map("t", "<M-e>", [[<C-\><C-n>]], { desc = "Leave terminal mode" })
map("n", "<leader>w", "<C-w>", { remap = true, desc = "Window command" })
map("n", "<leader><Up>", "<cmd>resize +2<CR>", { desc = "Grow window vertically" })
map("n", "<leader><Down>", "<cmd>resize -2<CR>", { desc = "Shrink window vertically" })
map("n", "<leader><Left>", "<cmd>vertical resize -2<CR>", { desc = "Shrink window horizontally" })
map("n", "<leader><Right>", "<cmd>vertical resize +2<CR>", { desc = "Grow window horizontally" })
map("n", "<leader>e", "<cmd>Vexplore<CR>", { desc = "File explorer" })
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })
map("n", "<leader>ff", "<cmd>Files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Rg<CR>", { desc = "Search text" })

if vim.fn.executable("sioyek") == 1 then
    vim.g.vimtex_view_method = "sioyek"
else
    vim.g.vimtex_view_method = "general"
    vim.g.vimtex_view_general_viewer = "xdg-open"
end
vim.g.vimtex_quickfix_mode = 0
if vim.fn.executable("tectonic") == 1 then
    vim.g.vimtex_compiler_method = "tectonic"
    vim.g.vimtex_compiler_tectonic = {
        options = { "--synctex", "--keep-logs", "--keep-intermediates" },
    }
elseif vim.fn.executable("latexmk") == 1 then
    vim.g.vimtex_compiler_method = "latexmk"
else
    -- Keep editing and completion available on machines where the optional
    -- document stack has not been installed yet.
    vim.g.vimtex_compiler_enabled = 0
end

local tex_group = vim.api.nvim_create_augroup("noctiri_tex_completion", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = tex_group,
    pattern = "tex",
    callback = function(args)
        vim.b[args.buf].noctiri_tex_live = true

        map("n", "<localleader>lx", function()
            vim.b.noctiri_tex_live = not vim.b.noctiri_tex_live
            local state = vim.b.noctiri_tex_live and "enabled" or "disabled"
            vim.notify("TeX compile-on-save " .. state, vim.log.levels.INFO)
            if vim.b.noctiri_tex_live and vim.fn.exists(":VimtexCompileSS") == 2 then
                vim.cmd("silent update")
                vim.cmd("silent VimtexCompileSS")
            end
        end, { buffer = args.buf, desc = "Toggle TeX compile on save" })
        map("n", "<localleader>lb", function()
            vim.cmd("silent update")
            vim.cmd("VimtexCompileSS")
        end, { buffer = args.buf, desc = "Build TeX once" })
        map("n", "<localleader>lv", function()
            local ok, pdf = pcall(vim.fn.eval, "b:vimtex.viewer.out()")
            if not ok or pdf == "" or vim.fn.filereadable(pdf) == 0 then
                vim.notify(
                    "No PDF exists yet. Finish the document, build with Space l b, then check :VimtexErrors if it fails.",
                    vim.log.levels.ERROR
                )
                return
            end
            vim.cmd("VimtexView")
        end, { buffer = args.buf, desc = "Open compiled TeX PDF" })
    end,
})

if vim.fn.executable("tectonic") == 1 then
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = tex_group,
        pattern = "*.tex",
        callback = function(args)
            if vim.b[args.buf].noctiri_tex_live ~= false
                and vim.fn.exists(":VimtexCompileSS") == 2 then
                vim.cmd("silent VimtexCompileSS")
            end
        end,
        desc = "Compile the TeX project with Tectonic after saving",
    })
    vim.api.nvim_create_autocmd("User", {
        group = tex_group,
        pattern = "VimtexEventCompileFailed",
        callback = function()
            vim.notify("TeX build failed. Run :VimtexErrors for the compiler errors.", vim.log.levels.ERROR)
        end,
        desc = "Explain failed TeX builds",
    })
end

vim.g.coc_global_extensions = { "coc-texlab" }

vim.cmd([[
function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1] =~# '\s'
endfunction

inoremap <silent><expr> <Tab>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <silent><expr> <S-Tab>
      \ coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
inoremap <silent><expr> <CR>
      \ coc#pum#visible() ? coc#pum#confirm() :
      \ "\<C-g>u\<CR>\<C-r>=coc#on_enter()\<CR>"
inoremap <silent><expr> <C-Space> coc#refresh()
]])

map("n", "gd", "<Plug>(coc-definition)", { silent = true, remap = true, desc = "Go to definition" })
map("n", "gr", "<Plug>(coc-references)", { silent = true, remap = true, desc = "Find references" })
map("n", "[d", "<Plug>(coc-diagnostic-prev)", { silent = true, remap = true, desc = "Previous diagnostic" })
map("n", "]d", "<Plug>(coc-diagnostic-next)", { silent = true, remap = true, desc = "Next diagnostic" })
map("n", "<leader>rn", "<Plug>(coc-rename)", { silent = true, remap = true, desc = "Rename symbol" })
map("n", "K", function()
    vim.fn.CocActionAsync("doHover")
end, { silent = true, desc = "Show documentation" })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop
if not uv.fs_stat(lazypath) then
    local result = vim.fn.system({
        "git", "clone", "--filter=blob:none", "--branch=stable",
        "https://github.com/folke/lazy.nvim.git", lazypath,
    })
    if vim.v.shell_error ~= 0 then
        vim.schedule(function()
            vim.notify("Could not install lazy.nvim:\n" .. result, vim.log.levels.ERROR)
        end)
    end
end
vim.opt.rtp:prepend(lazypath)

local lazy_ok, lazy = pcall(require, "lazy")
if lazy_ok then
    lazy.setup({
        { "junegunn/fzf", build = "./install --bin" },
        { "junegunn/fzf.vim", dependencies = { "junegunn/fzf" }, lazy = false },
        { "octol/vim-cpp-enhanced-highlight", ft = { "c", "cpp" } },
        {
            "neoclide/coc.nvim",
            branch = "release",
            lazy = false,
        },
        {
            "akinsho/toggleterm.nvim",
            version = "*",
            keys = {
                { "<leader>t", "<cmd>ToggleTerm direction=float<CR>", desc = "Floating terminal" },
                { "<leader>vt", "<cmd>ToggleTerm direction=vertical<CR>", desc = "Vertical terminal" },
                { "<leader>ht", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Horizontal terminal" },
            },
            opts = {
                open_mapping = [[<C-\>]],
                direction = "float",
                start_in_insert = true,
                persist_mode = true,
                shade_terminals = false,
                float_opts = {
                    border = "rounded",
                    winblend = 4,
                },
            },
        },
        -- VimTeX must be available before FileType events so inverse search and
        -- its project detection are reliable.
        { "lervag/vimtex", lazy = false },
    }, {
        change_detection = { notify = false },
        install = { colorscheme = { "noctalia" } },
    })
end

local theme_ok = pcall(vim.cmd.colorscheme, "noctalia")
if not theme_ok then
    vim.schedule(function()
        vim.notify(
            "Noctalia has not rendered the Neovim palette yet; run `noctalia msg templates-apply`.",
            vim.log.levels.WARN
        )
    end)
end
