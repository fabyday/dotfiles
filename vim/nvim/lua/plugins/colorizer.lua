return {
    "catgoose/nvim-colorizer.lua",
    event = "BufReadPre",
    opts = {
        filetypes = { "*" },
        user_default_options = {
            mode = "background",
            names = false,
            css = true,
        },
    },
}
