local M = {}
local has_overseer, Overseer = pcall(require, "overseer")

if not has_overseer then
    -- Keep the current npm workflow available while Overseer cannot be fetched.
    local dev_buf
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].npm_dev_server then
            dev_buf = buf
            break
        end
    end

    local function job_alive()
        if not (dev_buf and vim.api.nvim_buf_is_valid(dev_buf)) then
            return false
        end
        local job = vim.b[dev_buf].terminal_job_id
        return job and vim.fn.jobwait({ job }, 0)[1] == -1
    end

    local function find_dev_win()
        if not (dev_buf and vim.api.nvim_buf_is_valid(dev_buf)) then
            return nil
        end
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.api.nvim_win_get_buf(win) == dev_buf then
                return win
            end
        end
    end

    function M.toggle_dev()
        local win = find_dev_win()
        if win then
            vim.api.nvim_win_close(win, true)
            return
        end
        if job_alive() then
            vim.cmd("botright split")
            vim.cmd("resize 15")
            vim.api.nvim_win_set_buf(0, dev_buf)
            return
        end

        local root = vim.fs.root(0, "package.json") or vim.fn.getcwd()
        dev_buf = vim.api.nvim_create_buf(false, true)
        vim.b[dev_buf].npm_dev_server = true
        vim.g.cers_npm_dev_running = true
        vim.api.nvim_buf_call(dev_buf, function()
            vim.fn.jobstart({ "npm", "run", "dev" }, {
                term = true,
                cwd = root,
                on_exit = function()
                    vim.g.cers_npm_dev_running = false
                    vim.schedule(function() vim.cmd("redrawstatus") end)
                end,
            })
        end)
        vim.cmd("redrawstatus")
    end

    function M.stop_dev()
        if job_alive() then
            vim.fn.jobstop(vim.b[dev_buf].terminal_job_id)
        end
        if dev_buf and vim.api.nvim_buf_is_valid(dev_buf) then
            vim.api.nvim_buf_delete(dev_buf, { force = true })
        end
        dev_buf = nil
        vim.g.cers_npm_dev_running = false
        vim.cmd("redrawstatus")
    end

    vim.keymap.set("n", "<leader>nd", M.toggle_dev, { desc = "Toggle npm dev server" })
    vim.keymap.set("n", "<leader>r", M.toggle_dev, { desc = "Toggle npm dev server" })
    vim.keymap.set("n", "<leader>nk", M.stop_dev, { desc = "Stop npm dev server" })
    vim.notify("Overseer unavailable; using the existing npm terminal until it can be installed.", vim.log.levels.WARN)
    return M
end

local function project_root()
    return vim.fs.root(0, "package.json") or vim.fn.getcwd()
end

local function find_dev_task(root, only_running)
    local tasks = Overseer.list_tasks({
        filter = function(task)
            return task.metadata.cers_npm_dev == true
                and (root == nil or task.cwd == root)
                and (not only_running or task:is_running())
        end,
    })

    return tasks[1]
end

local function find_task_window(task)
    local buf = task:get_bufnr()
    if not buf then
        return nil
    end

    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == buf then
            return win
        end
    end
end

local function refresh_statusline()
    vim.schedule(function()
        vim.cmd("redrawstatus")
    end)
end

function M.toggle_dev()
    local root = project_root()
    local task = find_dev_task(root, true) or find_dev_task(nil, true)

    if task then
        local win = find_task_window(task)
        if win then
            vim.api.nvim_win_close(win, true)
        else
            task:open_output("horizontal")
        end
        return
    end

    task = find_dev_task(root, false)
    if task then
        task:restart(true)
        refresh_statusline()
        return
    end

    task = Overseer.new_task({
        name = "npm run dev",
        cmd = { "npm", "run", "dev" },
        cwd = root,
        metadata = { cers_npm_dev = true },
        components = {
            { "open_output", direction = "horizontal", focus = true, on_start = "never" },
            "default",
        },
    })
    task:subscribe("on_status", refresh_statusline)
    task:start()
    refresh_statusline()
end

function M.stop_dev()
    local task = find_dev_task(project_root(), true) or find_dev_task(nil, true)
    if task then
        task:stop()
    end
    refresh_statusline()
end

vim.keymap.set("n", "<leader>nd", M.toggle_dev, { desc = "Toggle npm dev server" })
vim.keymap.set("n", "<leader>r", M.toggle_dev, { desc = "Toggle npm dev server" })
vim.keymap.set("n", "<leader>nk", M.stop_dev, { desc = "Stop npm dev server" })

return M
