local function html_includeexpr()
    local filename = vim.v.fname

    -- Vite serves root-relative URLs such as /src/main.jsx from the project root.
    if filename:sub(1, 1) == "/" then
        local root = vim.fs.root(0, "package.json") or vim.fn.getcwd()
        local relative_path = filename:gsub("^/+", "")
        return vim.fs.joinpath(root, relative_path)
    end

    return filename
end

_G.cers_html_includeexpr = html_includeexpr

vim.api.nvim_create_autocmd("FileType", {
    pattern = "html",
    callback = function(args)
        vim.bo[args.buf].includeexpr = "v:lua.cers_html_includeexpr()"
    end,
    desc = "Resolve root-relative HTML paths from the project root",
})
