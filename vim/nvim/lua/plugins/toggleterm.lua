return {
    "akinsho/toggleterm.nvim",
    opts = {
        start_in_insert = false,
    },
    keys = {
        { "<leader>`", ":ToggleTerm size=10 direction=horizontal<CR>", desc = "Open bottom terminal", silent = true },
        { "<Esc>", [[<C-\><C-n>]], mode = "t", desc = "Leave terminal mode" },
    },
}
