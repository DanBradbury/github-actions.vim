if exists('g:loaded_github_actions')
  finish
endif
let g:loaded_github_actions = 1

command! -nargs=0 GithubActions call github_actions#view_workflows()
command! -nargs=0 GithubActionsToggle call github_actions#toggle()

autocmd FileType github_actions nnoremap <buffer> <CR> :call github_actions#open_workflow()<CR>

