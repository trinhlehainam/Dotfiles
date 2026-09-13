return {
  'nwiizo/codex.nvim',
  lazy = true,
  cmd = {
    'Codex',
    'CodexOpen',
    'CodexClose',
    'CodexFocus',
    'CodexStop',
    'CodexResume',
    'CodexContinue',
    'CodexFork',
    'CodexReview',
    'CodexImage',
    'CodexPrompt',
    'CodexAsk',
    'CodexAskVisual',
    'CodexFollowUp',
    'CodexEdit',
    'CodexDiff',
    'CodexInterrupt',
    'CodexSend',
    'CodexSendVisual',
    'CodexAddVisual',
    'CodexAdd',
    'CodexTreeAdd',
    'CodexSendText',
    'CodexStatus',
    'CodexHealth',
  },
  keys = {
    {
      '<leader>cc',
      function()
        require('codex').toggle()
      end,
      desc = 'Toggle Codex side-panel',
      mode = { 'n', 't' },
    },
    { '<leader>cx', '<cmd>CodexFocus<cr>', desc = 'Focus or hide Codex' },
    { '<leader>cb', '<cmd>CodexAdd<cr>', desc = 'Add current buffer to Codex' },
    { '<leader>ca', '<cmd>CodexAsk<cr>', desc = 'Ask Codex with file context' },
    {
      '<leader>cs',
      ':<C-U>CodexSendVisual<CR>',
      mode = 'v',
      desc = 'Send selection to Codex',
    },
  },
  opts = {
    backend = 'terminal',
    terminal = {
      layout = 'split',
      split_side = 'right',
      split_width_percentage = 0.4,
      hide_keys = { '<C-q>' },
    },
    selection = {
      -- Keep the shared <leader>a mappings available for Claude Code.
      keymaps = { ask = false, edit = false },
    },
  },
}
