vim9script
scriptencoding utf-8

import autoload 'github_actions.vim' as base

if exists('g:loaded_github_actions')
  finish
endif
g:loaded_github_actions = 1

command! -nargs=0 GithubActions base.ViewWorkflows()
