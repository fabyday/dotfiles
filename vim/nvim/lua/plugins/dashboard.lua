return {
    "nvimdev/dashboard-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
        theme = "doom",
        config = {
            header = {
                "",
                "",
                "YABAI NVIM",
                "",
            },
            center = {
                { icon = "+ ", desc = "New file", key = "n", action = ":ene" },
                { icon = "? ", desc = "Find file", key = "f", action = ":Telescope find_files hidden=true" },
                { icon = "/ ", desc = "Find text", key = "t", action = ":Telescope live_grep" },
                { icon = "L ", desc = "Lazy", key = "l", action = ":Lazy" },
                { icon = "Q ", desc = "Quit", key = "q", action = ":qa" },
            },
            footer = { "", "Have a great time with Neovim." },
        },
    },
}
