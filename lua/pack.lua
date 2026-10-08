vim.pack.add({
    "https://github.com/bluz71/vim-moonfly-colors",
    "https://github.com/EdenEast/nightfox.nvim",
    "https://github.com/folke/tokyonight.nvim",
    "https://github.com/nvim-mini/mini.nvim",
    "https://github.com/rafamadriz/friendly-snippets",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", branch = "main" },
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason.nvim",
})

require("nightfox").setup({
  options = {
    transparent = true,
  },
})

--- mini icons ---
-- до mini.files: он берёт иконки из MiniIcons
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- mini files ----
local MiniFiles = require("mini.files")
MiniFiles.setup({
    windows = {
        preview = true,
        width_preview = 50,
    },
    mappings = {
        go_in = "<CR>",
        go_in_plus = "L",
        go_out = "_",
        go_out_plus = "H",
    },
})

vim.keymap.set("n", "-", "<cmd>lua MiniFiles.open()<CR>", { desc = "Toggle mini file explorer" })
vim.keymap.set("n", "<leader>-", function()
    MiniFiles.open(vim.api.nvim_buf_get_name(0), false)
    MiniFiles.reveal_cwd()
end, { desc = "Toggle into currently opened file" })

--- mini tabline / bracketed / bufremove ---
-- вкладки буферов сверху, ]b/[b для переключения, закрытие без ломки окон
require("mini.tabline").setup()
require("mini.bracketed").setup()
require("mini.bufremove").setup()

vim.keymap.set("n", "<leader>bd", function() MiniBufremove.delete() end, { desc = "Close buffer (keep window)" })

---- mini notify ----
require("mini.notify").setup({
	-- only show messages
    content = {
        format = function(notif)
            return notif.msg
        end,
    },
})

--- mini cmdline completion ---
require("mini.cmdline").setup({
    autocorrect = { enable = false }
})

--- mini surround ---
-- префикс gs вместо s, чтобы не ломать встроенный `s`
require("mini.surround").setup({
    mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
    },
})
-- Keymaps
-- | `gsa` | Add surrounding or Direct with 'gsaiw' |
-- | `gsd` | Delete surrounding |
-- | `gsr` | Replace surrounding |
-- | `gsf` | Find surrounding (right) |
-- | `gsF` | Find surrounding (left) |
-- | `gsh` | Highlight surrounding |
-- | `gsn` | Update n_lines |
-- | `l` / `n` | as suffix for prev/next |

--- mini picker ---
local MiniPick = require("mini.pick")
local MiniExtra = require("mini.extra")
MiniPick.setup()
MiniExtra.setup()

-- keymaps
vim.keymap.set("n", "<leader>pf", function() MiniPick.builtin.files() end, { desc = "Mini File Picker" })
vim.keymap.set("n", "<leader>pb", function() MiniPick.builtin.buffers() end, { desc = "Mini Buffer Picker" })
vim.keymap.set("n", "<leader>ps",function() MiniPick.builtin.grep({ pattern = vim.fn.expand("<cword>") }) end, { desc = "Grep word/Search word" })
vim.keymap.set("n", "<leader>vh", function() MiniPick.builtin.help() end, { desc = "Mini Help" })

vim.keymap.set("n", "<leader>xx", function() MiniExtra.pickers.diagnostic() end, { desc = "Mini Picker Diagnostics" })
vim.keymap.set("n", "<leader>pk", function() MiniExtra.pickers.keymaps() end, { desc = 'Search keymaps' })

--- mini pairs ---
require("mini.pairs").setup()

--- mini completions ---
require("mini.completion").setup({
    lsp_completion = {
        auto_setup = true,
    }
})

--- mini snippets ---
local MiniSnippets = require("mini.snippets")
MiniSnippets.setup({
    snippets = {
        MiniSnippets.gen_loader.from_lang(), -- loads friendly-snippets
    },
})
MiniSnippets.start_lsp_server({ match = false })

-- undo/выход в normal-режим на середине сниппета оставляет "зависшие"
-- виртуальные плейсхолдеры (точки •/∎), т.к. сессия сниппета не следит за
-- undo - принудительно закрываем все активные сессии при выходе в normal
vim.api.nvim_create_autocmd("User", {
    pattern = "MiniSnippetsSessionStart",
    callback = function()
        vim.api.nvim_create_autocmd("ModeChanged", {
            pattern = "*:n",
            once = true,
            callback = function()
                while MiniSnippets.session.get() do
                    MiniSnippets.session.stop()
                end
            end,
        })
    end,
})

--- mini diff and lazygit ---
local MiniDiff = require("mini.diff")
MiniDiff.setup({
	source = MiniDiff.gen_source.git({ index = false }),
})

-- lazygit в плавающем окне, закрывается само после выхода (q)
vim.keymap.set("n", "<leader>gg", function()
    local buf = vim.api.nvim_create_buf(false, true)
    local w = math.floor(vim.o.columns * 0.9)
    local h = math.floor(vim.o.lines * 0.9)
    vim.api.nvim_open_win(buf, true, {
        relative = "editor", width = w, height = h,
        col = math.floor((vim.o.columns - w) / 2),
        row = math.floor((vim.o.lines - h) / 2),
        border = "rounded",
    })
    vim.fn.jobstart({ "lazygit" }, {
        term = true,
        on_exit = function()
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
            vim.cmd.checktime() -- перечитать файлы, если lazygit их поменял
        end,
    })
    vim.cmd.startinsert()
end, { desc = "LazyGit (float)" })

-- изменения прямо в буфере (вместо fugitive :Gvdiffsplit)
vim.keymap.set("n", "<leader>gd", function() MiniDiff.toggle_overlay() end, { desc = "Toggle git diff overlay" })
