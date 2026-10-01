return {
    "folke/snacks.nvim",
    priority = 1000,
    opts = {
        indent = {
            enabled = true,
            indent = { char = "|" },
            scope = { enabled = false },
        },
        bigfile = { enabled = true, notify = false },
        quickfile = { enabled = true },
    },
}
