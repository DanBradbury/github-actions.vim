vim9script
scriptencoding utf-8

if exists('g:loaded_github_actions')
  finish
endif
g:loaded_github_actions = 1

import autoload 'github_actions.vim' as base

def HandleEnterWrapper()
  base.HandleEnter()
enddef

command! -nargs=0 GithubActions base.ViewWorkflows()
command! -nargs=0 GithubActionsToggle base.ToggleWorkflowBuffer()

command! HandleEnterWrapper HandleEnterWrapper()
autocmd FileType github_actions nnoremap <buffer> <CR> :HandleEnterWrapper<CR>
