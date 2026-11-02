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
require("mini.git").setup()

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

local layout_socket
local main_keyboard_name
local pending_layouts = {}
local shutting_down = false

local function set_keyboard_layout(keymap)
    if not keymap then return end
    local normalized = keymap:lower()
    local layout = normalized:find("russian", 1, true) and "RU"
        or normalized:find("english", 1, true) and "EN"
        or keymap:sub(1, 2):upper()
    if vim.g.cers_keyboard_layout ~= layout then
        vim.g.cers_keyboard_layout = layout
        vim.cmd("redrawstatus")
    end
end

local function update_main_keyboard()
    vim.system({ "hyprctl", "devices", "-j" }, { text = true, timeout = 500 }, function(result)
        vim.schedule(function()
            if result.code ~= 0 then return end
            local ok, devices = pcall(vim.json.decode, result.stdout)
            if not ok or type(devices) ~= "table" or type(devices.keyboards) ~= "table" then return end

            for _, device in ipairs(devices.keyboards) do
                if device.main then
                    main_keyboard_name = device.name
                    set_keyboard_layout(pending_layouts[device.name] or device.active_keymap)
                    return
                end
            end
        end)
    end)
end

local function connect_layout_socket()
    local runtime_dir = vim.env.XDG_RUNTIME_DIR
    local instance = vim.env.HYPRLAND_INSTANCE_SIGNATURE
    if shutting_down or not runtime_dir or not instance then return end

    local pipe = vim.uv.new_pipe(false)
    layout_socket = pipe
    pipe:connect(runtime_dir .. "/hypr/" .. instance .. "/.socket2.sock", function(err)
        if err then
            pipe:close()
            if layout_socket == pipe then layout_socket = nil end
            if not shutting_down then vim.defer_fn(connect_layout_socket, 2000) end
            return
        end

        pending_layouts = {}
        update_main_keyboard()
        local pending = ""
        pipe:read_start(function(read_err, chunk)
            if read_err or not chunk then
                pipe:read_stop()
                if not pipe:is_closing() then pipe:close() end
                if layout_socket == pipe then layout_socket = nil end
                if not shutting_down then vim.defer_fn(connect_layout_socket, 2000) end
                return
            end

            pending = pending .. chunk
            for line in pending:gmatch("([^\n]*)\n") do
                local event, data = line:match("^([^>]+)>>(.*)$")
                if event == "activelayout" then
                    local keyboard, keymap = data:match("^([^,]+),(.+)$")
                    if keyboard and keymap then
                        pending_layouts[keyboard] = keymap
                        if keyboard == main_keyboard_name then
                            vim.schedule(function() set_keyboard_layout(keymap) end)
                        end
                    end
                end
            end
            pending = pending:match("[^\n]*$") or ""
        end)
    end)
end

update_main_keyboard()
connect_layout_socket()
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        shutting_down = true
        if layout_socket and not layout_socket:is_closing() then
            layout_socket:read_stop()
            layout_socket:close()
        end
    end,
    desc = "Close Hyprland keyboard layout listener",
})

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
            local keyboard_layout = vim.g.cers_keyboard_layout or ""
            local location = string.format("%d:%d", vim.fn.line("."), vim.fn.col("."))

            return MiniStatusline.combine_groups({
                { hl = "CersStatusMode", strings = { mode } },
                { hl = "CersStatusInfo", strings = { git } },
                "%<",
                "%=",
                { hl = "CersStatusServer", strings = { npm_status() } },
                { hl = "CersStatusFiletype", strings = { filetype } },
                { hl = "CersStatusInfo", strings = { keyboard_layout } },
                { hl = "CersStatusLocation", strings = { location } },
            })
        end,
    },
})

--- dashboard ---
local cers_logo = {
    "  _____  ______  _____   _____",
    " / ____| |  ____| |  __ \\ / ____|",
    "| |      | |__   | |__) | (___",
    "| |      |  __|  |  _  / \\___ \\ ",
    "| |____  | |____ | | \\ \\ ____) |",
    " \\_____| |______||_|  \\_\\_____/",
}

local clock_digits = {
    ["0"] = { " ████ ", "██  ██", "██  ██", "██  ██", " ████ " },
    ["1"] = { "  ██  ", " ███  ", "  ██  ", "  ██  ", "██████" },
    ["2"] = { "█████ ", "    ██", " █████", "██    ", "██████" },
    ["3"] = { "█████ ", "    ██", " █████", "    ██", "█████ " },
    ["4"] = { "██  ██", "██  ██", "██████", "    ██", "    ██" },
    ["5"] = { "██████", "██    ", "█████ ", "    ██", "█████ " },
    ["6"] = { " █████", "██    ", "█████ ", "██  ██", " ████ " },
    ["7"] = { "██████", "    ██", "   ██ ", "  ██  ", "  ██  " },
    ["8"] = { " ████ ", "██  ██", " ████ ", "██  ██", " ████ " },
    ["9"] = { " ████ ", "██  ██", " █████", "    ██", " ████ " },
    [":"] = { "      ", "  ██  ", "      ", "  ██  ", "      " },
}

local function clock_lines()
    local time = os.date("%H:%M")
    local lines = { "", "", "", "", "" }
    for char in time:gmatch(".") do
        for row = 1, 5 do
            lines[row] = lines[row] .. clock_digits[char][row] .. "  "
        end
    end
    return lines
end

local function dashboard_header()
    local header = { "" }
    vim.list_extend(header, clock_lines())
    vim.list_extend(header, { "" })
    vim.list_extend(header, cers_logo)
    vim.list_extend(header, { "" })
    return header
end

local function dashboard_footer()
    local version = vim.version()
    local startup_ms = (vim.uv.hrtime() - vim.g.cers_nvim_start_time) / 1e6
    local now = os.date("*t")
    local month_names = {
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December",
    }
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

    local first_day = os.time({ year = now.year, month = now.month, day = 1 })
    local first_column = (tonumber(os.date("%w", first_day)) + 6) % 7
    local days_in_month = os.date("*t", os.time({ year = now.year, month = now.month + 1, day = 0 })).day
    local weekdays = { "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su" }
    local weekday_line = {}
    for _, weekday in ipairs(weekdays) do
        weekday_line[#weekday_line + 1] = string.format("%-2s    ", weekday)
    end
    local calendar = { "", month_names[now.month] .. " " .. now.year, table.concat(weekday_line) }
    local week = {}
    for _ = 1, first_column do
        week[#week + 1] = "      "
    end
    for day = 1, days_in_month do
        week[#week + 1] = string.format("%2d%s   ", day, day == now.day and "*" or " ")
        if #week == 7 then
            calendar[#calendar + 1] = table.concat(week)
            week = {}
        end
    end
    while #week > 0 and #week < 7 do
        week[#week + 1] = "      "
    end
    if #week > 0 then calendar[#calendar + 1] = table.concat(week) end
    local footer = {
        "",
        "Neovim " .. version.major .. "." .. version.minor .. "." .. version.patch
            .. "  |  Startup " .. string.format("%.0f ms", startup_ms),
        vim.fn.fnamemodify(vim.uv.cwd(), ":~"),
        "Git branch: " .. branch,
    }
    vim.list_extend(footer, calendar)
    return footer
end

local calendar_namespace = vim.api.nvim_create_namespace("CersDashboardCalendar")
local function set_dashboard_calendar_highlight()
    local info = vim.api.nvim_get_hl(0, { name = "DiagnosticInfo", link = false })
    vim.api.nvim_set_hl(0, "CersDashboardCalendar", {
        fg = info.fg or 0x80CBC4,
        bg = "NONE",
        bold = true,
    })
end

local function position_dashboard_calendar(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "dashboard" then return end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local branch_row, month_row
    for row, line in ipairs(lines) do
        local content = vim.trim(line)
        if content:match("^Git branch:") then branch_row = row end
        if content:match("^%a+ %d%d%d%d$") then month_row = row end
    end
    if not branch_row or not month_row then return end

    local current_gap = month_row - branch_row - 1
    local extra_gap = math.max(0, 3 - current_gap)
    if extra_gap == 0 then return end
    local blanks = {}
    for _ = 1, extra_gap do
        blanks[#blanks + 1] = ""
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, month_row - 1, month_row - 1, false, blanks)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
end

local function highlight_dashboard_calendar(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "dashboard" then return end

    vim.api.nvim_buf_clear_namespace(buf, calendar_namespace, 0, -1)
    local in_calendar = false
    for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if vim.trim(line):match("^%a+ %d%d%d%d$") then in_calendar = true end
        if in_calendar then
            vim.api.nvim_buf_add_highlight(buf, calendar_namespace, "CersDashboardCalendar", row - 1, 0, -1)
        end
    end
end

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        set_dashboard_calendar_highlight()
        highlight_dashboard_calendar()
    end,
    desc = "Restore Dashboard calendar colors after colorscheme changes",
})

local dashboard_opts = {
    theme = "hyper",
    config = {
        header = dashboard_header(),
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
        footer = dashboard_footer,
    },
}

local Dashboard = require("dashboard")
Dashboard.setup(dashboard_opts)
local dashboard_clock_timer = vim.uv.new_timer()

local function refresh_dashboard_footer(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local branch_row
    for row, line in ipairs(lines) do
        if vim.trim(line):match("^Git branch:") then
            branch_row = row
            break
        end
    end
    if not branch_row then return end

    local footer_start = branch_row - 4
    local footer = require("dashboard.utils").center_align(dashboard_footer())
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, footer_start, -1, false, footer)
    for row = footer_start, footer_start + #footer - 1 do
        vim.api.nvim_buf_add_highlight(buf, 0, "DashboardFooter", row, 0, -1)
    end
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
    position_dashboard_calendar(buf)
    highlight_dashboard_calendar(buf)
end

local function refresh_dashboard_clock()
    local buf = vim.api.nvim_get_current_buf()
    if vim.bo[buf].filetype ~= "dashboard" then
        dashboard_clock_timer:stop()
        return
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for row, line in ipairs(lines) do
        if line:find("_____  ______  _____   _____", 1, true) then
            local clock_start = row - 7
            local digits = require("dashboard.utils").center_align(clock_lines())
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, clock_start, clock_start + #digits, false, digits)
            for i = 0, #digits - 1 do
                vim.api.nvim_buf_add_highlight(buf, 0, "DashboardHeader", clock_start + i, 0, -1)
            end
            vim.bo[buf].modifiable = false
            vim.bo[buf].modified = false
            break
        end
    end

    refresh_dashboard_footer(buf)
end

vim.api.nvim_create_autocmd("User", {
    pattern = "DashboardLoaded",
    callback = function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].filetype ~= "dashboard" then return end
        set_dashboard_calendar_highlight()
        position_dashboard_calendar(buf)
        highlight_dashboard_calendar(buf)
        local seconds = tonumber(os.date("%S")) or 0
        dashboard_clock_timer:stop()
        dashboard_clock_timer:start((60 - seconds) * 1000, 60000, vim.schedule_wrap(refresh_dashboard_clock))
    end,
    desc = "Update the Dashboard clock every minute",
})

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function() dashboard_clock_timer:stop() end,
    desc = "Stop the Dashboard clock",
})

vim.api.nvim_create_user_command("Dashboard", function()
    -- dashboard-nvim очищает свои настройки после закрытия стартовой страницы.
    -- Перед повторным открытием передаём их снова, чтобы избежать отложенного чтения
    -- настроек для буфера, который пользователь уже успел закрыть.
    dashboard_opts.config.header = dashboard_header()
    vim.g.cers_dashboard_calendar_gap = nil
    Dashboard.setup(dashboard_opts)
    Dashboard:instance()
end, { force = true, desc = "Open Dashboard" })

local dashboard_return_buf
vim.keymap.set("n", "<Esc>", function()
    local current_buf = vim.api.nvim_get_current_buf()
    local filetype = vim.bo[current_buf].filetype

    if filetype == "dashboard" then
        local return_buf = dashboard_return_buf
        if not return_buf or not vim.api.nvim_buf_is_valid(return_buf) then
            return_buf = vim.fn.bufnr("#")
        end
        if return_buf > 0 and return_buf ~= current_buf and vim.api.nvim_buf_is_valid(return_buf) then
            vim.api.nvim_set_current_buf(return_buf)
        end
        return
    end

    if filetype == "minifiles" then
        MiniFiles.close()
        return
    end

    -- Special/plugin buffers and floating windows should keep their own Esc
    -- behavior instead of trying to replace themselves with the Dashboard.
    if vim.bo[current_buf].buftype ~= "" or vim.api.nvim_win_get_config(0).relative ~= "" then
        return
    end

    dashboard_return_buf = current_buf
    vim.cmd("Dashboard")
end, { desc = "Toggle Dashboard" })

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

--- mini cursorword ---
require("mini.cursorword").setup()

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
