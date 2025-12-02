vim9script
scriptencoding utf-8

import autoload 'github_actions.vim' as base

if exists('g:loaded_github_actions')
  finish
endif
g:loaded_github_actions = 1


def HandleEnterWrapper()
  base.HandleEnter()
enddef

def OpenInGithubWrapper()
  base.OpenInGithub()
enddef

def OpenWorkflowFileWrapper()
  base.OpenWorkflowFile()
enddef

command! -nargs=0 GithubActions base.ViewWorkflows()

command! HandleEnterWrapper HandleEnterWrapper()
command! OpenInGithubWrapper OpenInGithubWrapper()
command! OpenWorkflowFileWrapper OpenWorkflowFileWrapper()
autocmd FileType github_actions nnoremap <buffer> <CR> :HandleEnterWrapper<CR>
autocmd FileType github_actions nnoremap <buffer> <C-o> :OpenInGithubWrapper<CR>
autocmd FileType github_actions nnoremap <buffer> gf :OpenWorkflowFileWrapper<CR>
