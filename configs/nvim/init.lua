vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.background = "dark"
vim.opt.termguicolors = true
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

local map = vim.keymap.set
map("n", "<leader>n", function()
    vim.opt.number = not vim.opt.number:get()
    vim.opt.relativenumber = vim.opt.number:get()
end, { desc = "Toggle line numbers" })
map("n", "<leader><CR>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "n", "nzz", { desc = "Next search result" })
map("n", "N", "Nzz", { desc = "Previous search result" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Close window" })
map("n", "<leader>t", "<cmd>vsplit | terminal<CR>", { desc = "Terminal in vertical split" })
map("n", "<leader><leader>t", "<cmd>terminal<CR>", { desc = "Terminal" })
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

vim.g.vimtex_view_method = "general"
vim.g.vimtex_view_general_viewer = "xdg-open"
vim.g.vimtex_quickfix_mode = 0
if vim.fn.executable("latexmk") == 1 then
    vim.g.vimtex_compiler_method = "latexmk"
else
    -- Void's lightweight texlive-latexmk package can exist without the full
    -- TeX Live tree. Keep editing/completion available without warning on
    -- every TeX buffer; compilation activates automatically once latexmk is.
    vim.g.vimtex_compiler_enabled = 0
end

local tex_group = vim.api.nvim_create_augroup("noctiri_tex_completion", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
    group = tex_group,
    pattern = "tex",
    callback = function(args)
        vim.bo[args.buf].omnifunc = "vimtex#complete#omnifunc"
        vim.bo[args.buf].complete = "o,.,w,b"
        pcall(function()
            vim.bo[args.buf].completefunc = ""
            vim.opt_local.completeopt = { "menuone", "popup", "fuzzy" }
            if vim.fn.exists("+autocomplete") == 1 then
                vim.opt_local.autocomplete = true
            end
            if vim.fn.exists("+autocompletedelay") == 1 then
                vim.opt_local.autocompletedelay = 100
            end
        end)
        map("i", "<Tab>", function()
            return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
        end, { buffer = args.buf, expr = true, silent = true })
        map("i", "<S-Tab>", function()
            return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
        end, { buffer = args.buf, expr = true, silent = true })
    end,
})

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
        { "lervag/vimtex", ft = { "tex", "plaintex" } },
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
