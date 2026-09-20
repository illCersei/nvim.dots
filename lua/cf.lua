local M = {}

vim.api.nvim_create_autocmd("BufNewFile", {
    pattern = "*.cpp",
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

    vim.cmd("botright split")
    vim.cmd("resize 15")
    vim.cmd("terminal " .. compile_cmd .. " && " .. vim.fn.shellescape(binary) .. " < " .. vim.fn.shellescape(input_file))
end

function M.edit_input()
    local dir = vim.fn.expand("%:p:h")
    local input_file = dir .. "/input.txt"
    vim.cmd("vsplit " .. input_file)
end

vim.keymap.set("n", "<leader>r", M.compile_and_run, { desc = "Compile & run CF solution" })
vim.keymap.set("n", "<leader>i", M.edit_input, { desc = "Edit input.txt" })

return M
