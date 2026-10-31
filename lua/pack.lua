vim.pack.add({
    "https://github.com/bluz71/vim-moonfly-colors",
    "https://github.com/EdenEast/nightfox.nvim",
    "https://github.com/folke/tokyonight.nvim",
    "https://github.com/nvim-mini/mini.nvim",
    "https://github.com/nvimdev/dashboard-nvim",
    "https://github.com/rafamadriz/friendly-snippets",
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", branch = "main" },
    "https://github.com/neovim/nvim-lspconfig",
    "https://github.com/mason-org/mason.nvim",
    "https://github.com/stevearc/conform.nvim",
    "https://github.com/windwp/nvim-ts-autotag",
    "https://github.com/b0o/SchemaStore.nvim",
    "https://github.com/mistweaverco/kulala.nvim",
})

-- Overseer optional install: Neovim should still start if GitHub is unavailable.
pcall(vim.pack.add, { "https://github.com/stevearc/overseer.nvim" })

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

--- overseer task runner and mini statusline ---
local has_overseer, Overseer = pcall(require, "overseer")
if has_overseer then
    Overseer.setup({
        task_list = { direction = "bottom" },
    })
end

local MiniStatusline = require("mini.statusline")

local function set_statusline_highlights()
    local function copy_foreground(target, source, bold)
        local source_hl = vim.api.nvim_get_hl(0, { name = source, link = false })
        vim.api.nvim_set_hl(0, target, {
            fg = source_hl.fg,
            bg = "NONE",
            bold = bold or false,
        })
    end

    copy_foreground("CersStatusMode", "Normal", true)
    copy_foreground("CersStatusInfo", "MiniStatuslineDevinfo")
    copy_foreground("CersStatusServer", "DiagnosticOk", true)
    copy_foreground("CersStatusFiletype", "MiniStatuslineFileinfo")
    copy_foreground("CersStatusLocation", "Normal")
    copy_foreground("StatusLine", "Normal")
    copy_foreground("StatusLineNC", "Normal")
    copy_foreground("MiniStatuslineInactive", "Normal")
end

set_statusline_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
    callback = set_statusline_highlights,
    desc = "Keep CERS statusline transparent",
})

local function npm_status()
    if has_overseer then
        local tasks = Overseer.list_tasks({ status = "RUNNING" })
        for _, task in ipairs(tasks) do
            if task.metadata.cers_npm_dev then
                return "npm: RUNNING"
            end
        end
    end
    return vim.g.cers_npm_dev_running and "npm: RUNNING" or ""
end

MiniStatusline.setup({
    content = {
        active = function()
            local mode = MiniStatusline.section_mode({ trunc_width = 120 })
            local git = MiniStatusline.section_git({ trunc_width = 80, icon = "" })
            local filetypes = {
                javascript = "JS",
                javascriptreact = "JSX",
                typescript = "TS",
                typescriptreact = "TSX",
            }
            local filetype = filetypes[vim.bo.filetype] or vim.bo.filetype:upper()
            local location = string.format("%d:%d", vim.fn.line("."), vim.fn.col("."))

            return MiniStatusline.combine_groups({
                { hl = "CersStatusMode", strings = { mode } },
                { hl = "CersStatusInfo", strings = { git } },
                "%<",
                "%=",
                { hl = "CersStatusServer", strings = { npm_status() } },
                { hl = "CersStatusFiletype", strings = { filetype } },
                { hl = "CersStatusLocation", strings = { location } },
            })
        end,
    },
})

--- dashboard ---
require("dashboard").setup({
    theme = "hyper",
    config = {
        header = {
            "",
            "  _____  ______  _____   _____",
            " / ____| |  ____| |  __ \\ / ____|",
            "| |      | |__   | |__) | (___",
            "| |      |  __|  |  _  / \\___ \\ ",
            "| |____  | |____ | | \\ \\ ____) |",
            " \\_____| |______||_|  \\_\\_____/",
            "",
        },
        shortcut = {
            {
                icon = "  ",
                desc = "Find File",
                key = "f",
                action = "lua require('mini.pick').builtin.files()",
            },
            {
                desc = "New File",
                key = "n",
                action = "enew",
            },
            {
                desc = "Edit Config",
                key = "c",
                action = "lua vim.cmd.edit(vim.fn.stdpath('config') .. '/init.lua')",
            },
            {
                desc = "Quit",
                key = "q",
                action = "qa",
            },
        },
        packages = { enable = false },
        project = { enable = false },
        mru = { enable = true, limit = 8, icon = "  ", label = "Recent Files", cwd_only = false },
        footer = function()
            local version = vim.version()
            local startup_ms = (vim.uv.hrtime() - vim.g.cers_nvim_start_time) / 1e6
            local root = vim.fs.root(vim.uv.cwd(), { ".git" })
            local branch = "not a Git repo"

            if root then
                local result = vim.system({ "git", "-C", root, "branch", "--show-current" }, { text = true }):wait()
                if result.code == 0 and result.stdout ~= "" then
                    branch = vim.trim(result.stdout)
                else
                    branch = "detached HEAD"
                end
            end

            return {
                "Neovim " .. version.major .. "." .. version.minor .. "." .. version.patch
                    .. "  |  Startup " .. string.format("%.0f ms", startup_ms),
                "Git branch: " .. branch,
            }
        end,
    },
})

vim.keymap.set("n", "<Esc>", "<cmd>Dashboard<CR>", { desc = "Open Dashboard" })

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

--- autotag ---
-- <div> сам закрывается </div>, переименование открывающего тега меняет и закрывающий
require("nvim-ts-autotag").setup()

--- mini hipatterns ---
-- #ff0000 подсвечивается своим цветом, TODO/FIXME/HACK/NOTE выделяются
local hipatterns = require("mini.hipatterns")
hipatterns.setup({
    highlighters = {
        fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
        hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
        todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
        note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },
        hex_color = hipatterns.gen_highlighter.hex_color(),
    },
})

--- kulala ---
-- запросы к API из .http файлов (как REST Client в vscode), маппинги на <leader>R*
require("kulala").setup({ global_keymaps = true })

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
        MiniSnippets.gen_loader.from_lang({ -- loads friendly-snippets
            lang_patterns = {
                -- .tsx: сниппеты ищутся по имени языка "tsx", а в friendly-snippets
                -- их нет - подключаем ts + react (хуки и rafce лежат в react-es7)
                tsx = { "**/typescript.json", "javascript/react-ts.json", "javascript/react-es7.json" },
            },
        }),
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
