-- Unreal reflection completion alongside the existing clangd + mini.completion.
require("unreal-sense").setup({
    engine_path = "/mnt/projects/Unreal/UE_5.8.4",
    lsp = false, -- Keep our existing clangd configuration.
    auto_setup = false,
    poll_interval = 0,
})
-- Keep the working compilation database; regenerate explicitly when needed.
vim.api.nvim_clear_autocmds({ group = "UnrealSenseAutoRegen" })

local project = require("unreal-sense.project")
local init = assert(vim.api.nvim_get_runtime_file("lua/unreal-sense/init.lua", false)[1])
local plugin_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(init)))

-- Register normally so :lsp restart can restart this server too.
vim.lsp.config("unreal_lsp", {
    -- The server advertises incremental sync but treats changes as full text.
    -- Send full documents so typing does not destroy its macro context.
    flags = { allow_incremental_sync = false },
    cmd = function(dispatchers, config)
        return vim.lsp.rpc.start({
            "python3",
            vim.fs.joinpath(plugin_root, "tools", "unreal-lsp", "unreal_lsp.py"),
            "--project-root", config.root_dir,
            "--engine-path", "/mnt/projects/Unreal/UE_5.8.4",
        }, dispatchers)
    end,
    filetypes = { "cpp", "c", "objc", "objcpp" },
    root_dir = function(bufnr, on_dir)
        local uproject = project.find_from(vim.api.nvim_buf_get_name(bufnr))
        if uproject then on_dir(project.get_root(uproject)) end
    end,
})
vim.lsp.enable("unreal_lsp")

-- Inside reflection macros show UE specifiers rather than unrelated C++ symbols.
local completion = require("mini.completion")
local process_items = completion.config.lsp_completion.process_items
completion.config.lsp_completion.process_items = function(items, base)
    local prefix = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
    local in_macro = false
    for _, macro in ipairs({ "UPROPERTY", "UFUNCTION", "UCLASS", "USTRUCT", "UENUM" }) do
        if prefix:match(macro .. "%s*%([^)]*$") then in_macro = true; break end
    end
    if in_macro then
        items = vim.tbl_filter(function(item)
            local client = item.client_id and vim.lsp.get_client_by_id(item.client_id)
            return client and client.name == "unreal_lsp"
        end, items)
    end
    return process_items(items, base)
end
