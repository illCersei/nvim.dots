local M = {}

local term_win = nil

-- находит окно в текущем табе, где открыт буфер с данным путём
local function find_win_by_file(path)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_get_name(buf) == path then
            return win
        end
    end
    return nil
end

vim.api.nvim_create_autocmd("BufNewFile", {
    pattern = "[a-zA-Z].cpp", -- только однобуквенные имена задач: a.cpp, b.cpp, ...
    callback = function()
        local template = vim.fn.stdpath("config") .. "/templates/template.cpp"
        if vim.fn.filereadable(template) == 1 then
            vim.cmd("0r " .. template)
            vim.cmd("normal! Gdd") -- убрать лишнюю пустую строку в конце после вставки
            vim.fn.cursor(1, 1)
            vim.fn.search("CURSOR")
            vim.cmd("normal! cc")
            vim.cmd("startinsert")
        end
    end,
})

function M.compile_and_run()
    vim.cmd("write")
    local file = vim.fn.expand("%:p")
    local dir = vim.fn.expand("%:p:h")
    local name = vim.fn.expand("%:t:r")
    local binary = dir .. "/" .. name

    local input_file = dir .. "/input.txt"
    if vim.fn.filereadable(input_file) == 0 then
        vim.fn.writefile({}, input_file)
    end

    local compile_cmd = string.format(
        "g++ -std=c++17 -O2 -Wall -Wshadow -o %s %s",
        vim.fn.shellescape(binary), vim.fn.shellescape(file)
    )

    -- если терминал от прошлого запуска ещё открыт - закрываем,
    -- чтобы не копились сплиты при повторных <leader>r
    if term_win and vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
    end

    vim.cmd("botright split")
    vim.cmd("resize 15")
    term_win = vim.api.nvim_get_current_win()
    vim.cmd("terminal " .. compile_cmd .. " && " .. vim.fn.shellescape(binary) .. " < " .. vim.fn.shellescape(input_file))
end

function M.edit_input()
    local dir = vim.fn.expand("%:p:h")
    local input_file = dir .. "/input.txt"

    local win = find_win_by_file(input_file)
    if win then
        vim.api.nvim_set_current_win(win)
        return
    end

    vim.cmd("vsplit " .. vim.fn.fnameescape(input_file))
end

vim.keymap.set("n", "<leader>r", M.compile_and_run, { desc = "Compile & run CF solution" })
vim.keymap.set("n", "<leader>i", M.edit_input, { desc = "Edit input.txt" })

return M
