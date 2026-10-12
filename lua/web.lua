local M = {}

local dev_buf = nil

-- окно в текущем табе, где показан буфер dev-сервера
local function find_dev_win()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_buf(win) == dev_buf then
            return win
        end
    end
    return nil
end

local function job_alive()
    if not (dev_buf and vim.api.nvim_buf_is_valid(dev_buf)) then
        return false
    end
    local job = vim.b[dev_buf].terminal_job_id
    return job and vim.fn.jobwait({ job }, 0)[1] == -1
end

-- npm run dev в нижнем терминале: первый вызов запускает,
-- дальше прячет/показывает окно (сервер продолжает работать)
function M.toggle_dev()
    local win = find_dev_win()
    if win then
        vim.api.nvim_win_close(win, true)
        return
    end

    vim.cmd("botright split")
    vim.cmd("resize 15")

    if job_alive() then
        vim.api.nvim_win_set_buf(0, dev_buf)
        return
    end

    -- корень проекта: ближайшая папка с package.json
    local root = vim.fs.root(0, "package.json") or vim.fn.getcwd()
    vim.cmd("enew")
    dev_buf = vim.api.nvim_get_current_buf()
    vim.fn.jobstart({ "npm", "run", "dev" }, { term = true, cwd = root })
end

-- остановить сервер (Ctrl-C в терминал) и закрыть буфер
function M.stop_dev()
    if job_alive() then
        vim.fn.jobstop(vim.b[dev_buf].terminal_job_id)
    end
    if dev_buf and vim.api.nvim_buf_is_valid(dev_buf) then
        vim.api.nvim_buf_delete(dev_buf, { force = true })
    end
    dev_buf = nil
end

vim.keymap.set("n", "<leader>nd", M.toggle_dev, { desc = "npm run dev (toggle terminal)" })
vim.keymap.set("n", "<leader>nk", M.stop_dev, { desc = "Kill npm dev server" })

-- <leader>r в веб-файлах = то же, что <leader>nd (в c++ и go у него свои действия)
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "vue", "javascript", "typescript", "javascriptreact", "typescriptreact", "html", "css", "scss" },
    callback = function(args)
        vim.keymap.set("n", "<leader>r", M.toggle_dev, { buffer = args.buf, desc = "npm run dev (toggle terminal)" })
    end,
})

return M
