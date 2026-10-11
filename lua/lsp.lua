require("mason").setup()

vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { desc = "Go to definition" })
-- фронт форматирует prettierd, остальное как раньше через LSP
require("conform").setup({
    formatters_by_ft = {
        vue = { "prettierd" },
        javascript = { "prettierd" },
        typescript = { "prettierd" },
        javascriptreact = { "prettierd" },
        typescriptreact = { "prettierd" },
        css = { "prettierd" },
        scss = { "prettierd" },
        html = { "prettierd" },
        json = { "prettierd" },
    },
    default_format_opts = { lsp_format = "fallback" },
})

vim.keymap.set("n", "<leader>f", function() require("conform").format() end, { desc = "Format Local buffer" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show line diagnostics" })

vim.diagnostic.config({ virtual_text = true })

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = vim.tbl_deep_extend("force", capabilities, require("mini.completion").get_lsp_capabilities())

vim.lsp.config("*", { capabilities = capabilities })

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            diagnostics = { globals = { "vim" } },
        },
    },
})

-- vue: vue_ls работает только в паре с vtsls, который подхватывает
-- @vue/typescript-plugin из пакета vue-language-server (ставится через mason)
vim.lsp.config("vtsls", {
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
    settings = {
        vtsls = {
            tsserver = {
                globalPlugins = {
                    {
                        name = "@vue/typescript-plugin",
                        location = vim.fn.stdpath("data")
                            .. "/mason/packages/vue-language-server/node_modules/@vue/language-server",
                        languages = { "vue" },
                        configNamespace = "typescript",
                    },
                },
            },
        },
    },
})

-- схемы для package.json, tsconfig.json и т.д. (автодополнение ключей)
vim.lsp.config("jsonls", {
    settings = {
        json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
        },
    },
})

vim.lsp.enable({
    "lua_ls",
    "marksman",
    "gopls",
    "rust_analyzer",
    "clangd",
    "vtsls",
    "vue_ls",
    "eslint",
    "emmet_language_server",
    "tailwindcss", -- включается только в проектах с tailwind
    "cssls",
    "html",
    "jsonls",
})

