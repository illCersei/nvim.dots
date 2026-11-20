local M = { running = false }
local engine = "/mnt/projects/Unreal/UE_5.8.4"
local last_log

local function notify(text, level)
    vim.notify(text, level or vim.log.levels.INFO, { title = "Unreal Build" })
end

local function start_progress(target)
    local mini = require("mini.notify")
    local started = vim.uv.hrtime()
    local stage = "Подготовка"
    local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local frame = 0
    local active = true
    local id = mini.add("⠋ Unreal: " .. target .. " — подготовка", "INFO", nil, { source = "unreal_build" })
    local timer = vim.uv.new_timer()
    local function elapsed() return (vim.uv.hrtime() - started) / 1e9 end
    local function render()
        if not active then return end
        frame = frame % #frames + 1
        pcall(mini.update, id, { msg = string.format("%s Unreal: %s | %.0f с\n%s", frames[frame], target, elapsed(), stage) })
    end
    timer:start(0, 150, vim.schedule_wrap(render))
    local progress = {}
    function progress.line(line)
        if not active then return end
        local done, total, action = line:match("^%[(%d+)/(%d+)%]%s*(.*)")
        if done then stage = string.format("%s/%s — %s", done, total, action)
        elseif line:find("Parsing headers", 1, true) or line:find("UnrealHeaderTool", 1, true) then stage = "Генерация заголовков (UHT)"
        elseif line:find("Creating makefile", 1, true) then stage = "Подготовка сборки"
        elseif line:find("Target is up to date", 1, true) then stage = "Изменений нет"
        elseif line:find("Building ", 1, true) then stage = "Компиляция"
        end
    end
    function progress.finish(success, detail)
        active = false
        timer:stop(); timer:close()
        local msg = string.format("%s Unreal: %s | %.1f с\n%s", success and "✓" or "✗", target, elapsed(), detail)
        pcall(mini.update, id, { msg = msg, level = success and "INFO" or "ERROR" })
        vim.defer_fn(function() mini.remove(id) end, success and 5000 or 10000)
    end
    return progress
end

function M.build()
    if M.running then notify("Сборка уже выполняется"); return end
    local bufnr = vim.api.nvim_get_current_buf()
    local uproject = require("unreal-sense.project").find_from(vim.api.nvim_buf_get_name(bufnr))
    if not uproject then notify("Открой файл Unreal-проекта", vim.log.levels.WARN); return end
    local root = vim.fs.dirname(uproject)
    local targets = vim.fn.glob(root .. "/Source/*Editor.Target.cs", false, true)
    if #targets ~= 1 then notify("Не удалось однозначно определить Editor.Target.cs", vim.log.levels.ERROR); return end
    local target = vim.fs.basename(targets[1]):gsub("%.Target%.cs$", "")

    -- Save only modified project files, leaving unrelated buffers alone.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if vim.bo[buf].modified and vim.bo[buf].buftype == "" and name:sub(1, #root + 1) == root .. "/" then
            local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("update") end)
            if not ok then notify("Не удалось сохранить: " .. tostring(err), vim.log.levels.ERROR); return end
        end
    end

    local log_dir = vim.fn.stdpath("state") .. "/unreal-build"
    vim.fn.mkdir(log_dir, "p")
    last_log = log_dir .. "/" .. vim.fn.sha256(root):sub(1, 12) .. ".log"
    M.running = true
    local progress = start_progress(target)
    local chunks = {}
    local pending = { stdout = "", stderr = "" }
    local function stream(channel)
        return function(_, data)
            if not data then return end
            chunks[#chunks + 1] = data
            vim.schedule(function()
                local text = pending[channel] .. data:gsub("\r", "\n")
                local lines = vim.split(text, "\n", { plain = true })
                pending[channel] = table.remove(lines)
                for _, line in ipairs(lines) do progress.line(line) end
            end)
        end
    end
    local ok, err = pcall(vim.system, {
        engine .. "/Engine/Build/BatchFiles/Linux/Build.sh",
        target, "Linux", "Development", "-Project=" .. uproject, "-WaitMutex",
    }, { cwd = root, text = true, stdout = stream("stdout"), stderr = stream("stderr") }, vim.schedule_wrap(function(result)
        M.running = false
        local output = table.concat(chunks)
        local lines = vim.split(output, "\n", { plain = true })
        vim.fn.writefile(lines, last_log)
        if result.code == 0 then
            -- Reopen clangd's translation units to pick up newly generated headers.
            local attached = vim.api.nvim_buf_is_valid(bufnr)
                and #vim.lsp.get_clients({ bufnr = bufnr, name = "clangd" }) > 0
            if attached then
                vim.api.nvim_buf_call(bufnr, function() vim.cmd("lsp restart clangd") end)
            end
            progress.finish(true, attached and "Сборка успешна · clangd обновлён" or "Сборка успешна")
        else
            local efm = table.concat({
                "%f:%l:%c: error: %m", "%f:%l: error: %m",
                "%f(%l): Error: %m", "%f(%l): error: %m",
                "%f:%l:%c: fatal error: %m", "%-G%.%#",
            }, ",")
            local parsed = vim.fn.getqflist({ lines = lines, efm = efm }).items
            local valid = vim.tbl_filter(function(item) return item.valid == 1 end, parsed)
            vim.fn.setqflist({}, " ", { title = "Unreal: " .. target, items = valid })
            if #valid > 0 then vim.cmd("copen") else M.show_log() end
            progress.finish(false, "Ошибка сборки · :UnrealBuildLog")
        end
    end))
    if not ok then M.running = false; progress.finish(false, tostring(err)) end
end

function M.show_log()
    if not last_log or vim.fn.filereadable(last_log) == 0 then notify("Журнала сборки пока нет"); return end
    vim.cmd("botright split " .. vim.fn.fnameescape(last_log))
    vim.bo.readonly = true
    vim.bo.modifiable = false
end

vim.api.nvim_create_user_command("UnrealBuild", M.build, { desc = "Build Unreal project and refresh clangd" })
vim.api.nvim_create_user_command("UnrealBuildLog", M.show_log, { desc = "Show last Unreal build output" })
vim.keymap.set("n", "<F5>", M.build, { desc = "Build Unreal project" })
return M
