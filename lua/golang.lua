local M = {}

local term_win = nil

-- команда в нижнем терминале; прошлый терминал закрывается, чтобы не копились сплиты
local function run_in_term(cmd, cwd)
    vim.cmd("silent! wall")

    if term_win and vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
    end

    vim.cmd("botright split")
    vim.cmd("resize 15")
    term_win = vim.api.nvim_get_current_win()
    vim.cmd("enew")
    vim.fn.jobstart(cmd, { term = true, cwd = cwd })
end

-- корень модуля (папка с go.mod); без него не запускаем, а подсказываем go mod init
local function module_root()
    local root = vim.fs.root(0, "go.mod")
    if not root then
        vim.notify("Нет go.mod: выполни go mod init <имя> в папке проекта", vim.log.levels.ERROR)
    end
    return root
end

-- go run . в папке текущего файла (работает и для main.go в корне, и для cmd/app/main.go)
function M.run()
    if module_root() then
        run_in_term({ "go", "run", "." }, vim.fn.expand("%:p:h"))
    end
end

-- все тесты модуля из корня
function M.test()
    local root = module_root()
    if root then
        run_in_term({ "go", "test", "./..." }, root)
    end
end

-- хоткеи только в go-файлах
vim.api.nvim_create_autocmd("FileType", {
    pattern = "go",
    callback = function(args)
        vim.keymap.set("n", "<leader>r", M.run, { buffer = args.buf, desc = "go run ." })
        vim.keymap.set("n", "<leader>ct", M.test, { buffer = args.buf, desc = "go test ./..." })
    end,
})

return M
