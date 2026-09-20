vim.pack.add({
    "https://github.com/bluz71/vim-moonfly-colors",
    "https://github.com/EdenEast/nightfox.nvim",
    "https://github.com/folke/tokyonight.nvim",
    "https://github.com/nvim-mini/mini.nvim",
    "https://github.com/rafamadriz/friendly-snippets",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", branch = "main" },
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason.nvim",
    "https://github.com/tpope/vim-fugitive",
})

require("nightfox").setup({
  options = {
    transparent = true,
  },
})

-- mini files ----
local MiniFiles = require("mini.files")
MiniFiles.setup({
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
require("mini.surround").setup()
-- Default Keymaps
-- | `sa` | Add surrounding or Direct with 'saiw' |
-- | `sd` | Delete surrounding |
-- | `sr` | Replace surrounding |
-- | `sf` | Find surrounding (right) |
-- | `sF` | Find surrounding (left) |
-- | `sh` | Highlight surrounding |
-- | `sn` | Update n_lines |
-- | `l` / `n` | as suffix for prev/next |

--- mini picker ---
local MiniPick = require("mini.pick")
local MiniExtra = require("mini.extra")
MiniPick.setup()
MiniExtra.setup()

-- keymaps
vim.keymap.set("n", "<leader>pf", function() MiniPick.builtin.files() end, { desc = "Mini File Picker" })
vim.keymap.set("n", "<leader>ps", function() MiniPick.builtin.grep({ pattern = vim.fn.expand("<cword>") }) end, { desc = "Grep word/Search word" })
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

-- по умолчанию expand() матчит сниппеты даже на пустом месте (это нужно для
-- попапа автодополнения) - для <Tab> нужен матч только если реально что-то
-- напечатано перед курсором, иначе <Tab> будет всегда "разворачивать"
local match_strict = function(snips)
    return MiniSnippets.default_match(snips, { pattern_fuzzy = "%S+" })
end

MiniSnippets.setup({
    snippets = {
        MiniSnippets.gen_loader.from_lang(), -- loads friendly-snippets
    },
    -- отключаем дефолтные <C-l>/<C-h>/<C-j> - переезжаем на Tab/S-Tab ниже
    mappings = { expand = "", jump_next = "", jump_prev = "" },
    expand = { match = match_strict },
})
MiniSnippets.start_lsp_server({ match = false })

-- "Supertab"-style <Tab>/<S-Tab>: сначала листает попап автодополнения
-- (как в Atom), потом разворачивает/прыгает по сниппету, и только если
-- ни то ни другое не активно - вставляет обычный таб
local function keycode(str)
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

vim.keymap.set("i", "<Tab>", function()
    if vim.fn.pumvisible() == 1 then
        return keycode("<C-n>")
    end
    if #MiniSnippets.expand({ insert = false }) > 0 then
        vim.schedule(MiniSnippets.expand)
        return ""
    end
    if MiniSnippets.session.get() ~= nil then
        MiniSnippets.session.jump("next")
        return ""
    end
    return keycode("<Tab>")
end, { expr = true, desc = "Next completion / expand snippet / jump next tabstop" })

vim.keymap.set("i", "<S-Tab>", function()
    if vim.fn.pumvisible() == 1 then
        return keycode("<C-p>")
    end
    if MiniSnippets.session.get() ~= nil then
        MiniSnippets.session.jump("prev")
        return ""
    end
    return keycode("<S-Tab>")
end, { expr = true, desc = "Prev completion / jump prev tabstop" })

--- mini diff and fugitive ---
local MiniDiff = require("mini.diff")
MiniDiff.setup({
	source = MiniDiff.gen_source.git({ index = false }),
})

vim.keymap.set("n", "<leader>gg", "<cmd>tabnew | Git | only<cr>", { desc = "Fugitive Full Page New Tab" })
vim.keymap.set("n", "<leader>gd", "<cmd>Gvdiffsplit<CR>", { desc = "Git diff split", })
