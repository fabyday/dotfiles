return {
    "nvim-mini/mini.nvim",
    config = function()
        require("mini.pairs").setup()
        require("mini.surround").setup()
        require("mini.comment").setup({
            ignore_blank_line = true,
        })

        vim.keymap.set("n", "<leader>/", "gcc", { remap = true, desc = "Toggle comment" })
        vim.keymap.set("v", "<leader>/", "gc", { remap = true, desc = "Toggle comment" })
    end,
}
