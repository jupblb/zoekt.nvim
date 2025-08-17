-- Minimal init file for running tests
-- Expects plenary.nvim to be available in Neovim runtime

vim.opt.rtp:append('.')

vim.cmd('runtime plugin/plenary.vim')
require('plenary.busted')
