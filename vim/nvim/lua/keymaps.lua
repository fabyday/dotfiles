local keymap = vim.keymap.set

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

keymap("n", "<leader>rn", ":set relativenumber!<CR>", { desc = "Toggle relative number", silent = true })
keymap("n", "<Esc>", ":nohlsearch<CR>", { desc = "Clear search highlights", silent = true })

keymap("n", "<leader>rp", "<C-w>+", { desc = "Make window taller" })
keymap("n", "<leader>rm", "<C-w>-", { desc = "Make window shorter" })
keymap("n", "<leader>r.", "<C-w>>", { desc = "Make window wider" })
keymap("n", "<leader>r,", "<C-w><", { desc = "Make window narrower" })

keymap("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
keymap("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

keymap("n", "<A-Up>", ":m .-2<CR>==", { desc = "Move line up", silent = true })
keymap("n", "<A-Down>", ":m .+1<CR>==", { desc = "Move line down", silent = true })
keymap("v", "<A-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })
keymap("v", "<A-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })

keymap("n", "<Tab>", ">>", { desc = "Indent line" })
keymap("n", "<S-Tab>", "<<", { desc = "Unindent line" })
keymap("v", "<Tab>", ">gv", { desc = "Indent selection" })
keymap("v", "<S-Tab>", "<gv", { desc = "Unindent selection" })
