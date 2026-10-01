return {
    "saghen/blink.cmp",
    dependencies = {
        "rafamadriz/friendly-snippets",
        {
            "saghen/blink.compat",
            optional = true,
            version = "*",
        },
    },
    version = "*",
    opts = {
        keymap = { preset = "super-tab" },
        appearance = { nerd_font_variant = "mono" },
        completion = {
            menu = { border = "rounded" },
            ghost_text = { enabled = true },
            documentation = {
                auto_show = true,
                auto_show_delay_ms = 200,
                window = { border = "rounded" },
            },
        },
        signature = { enabled = true },
        sources = {
            default = { "lsp", "path", "snippets", "buffer" },
        },
        fuzzy = { implementation = "prefer_rust_with_warning" },
    },
    opts_extend = { "sources.default" },
}
