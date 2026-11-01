vim.g.cers_nvim_start_time = vim.uv.hrtime()

require("vim._core.ui2").enable({})

require("options")
require("keymaps")
require("commands")
require("pack")
require("treesitter")
require("lsp")
require("cf")
require("web")
require("html")
require("golang")

vim.cmd.colorscheme("nightfox")
