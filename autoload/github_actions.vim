scriptencoding utf-8

function!github_actions#view_workflows() abort
  " Check if the buffer already exists
  for l:buf in range(1, bufnr('$'))
    if bufname(l:buf) ==# 'GitHub Actions'
      " If the buffer exists, switch to it
      execute 'buffer ' . l:buf
      return
    endif
  endfor

  " Determine the side to open the buffer
  if !exists('g:github_actions_window_side')
    let g:github_actions_window_side = 'left' " Default to left
  endif

  if g:github_actions_window_side ==# 'left'
    execute 'topleft vnew'
  elseif g:github_actions_window_side ==# 'right'
    execute 'botright vnew'
  else
    echoerr "Invalid value for g:github_actions_window_side. Use 'left' or 'right'."
    return
  endif

  " Set the buffer options for the sidebar
  execute 'file GitHub Actions'
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  setlocal nonumber
  setlocal norelativenumber
  setlocal foldcolumn=0
  setlocal signcolumn=no

  " Set the width of the sidebar
  if !exists('g:github_actions_window_size')
    let g:github_actions_window_size = '50'
  endif

  execute 'vertical resize ' . g:github_actions_window_size

  " Add the "GitHub Actions" header with styling
   call setline(1, '===========================')
   call setline(2, '      GitHub Actions')
   call setline(3, '===========================')
   call setline(4, '') " Add a blank line

  " Check if the current directory is a Git repository
  let l:is_git_repo = system('git rev-parse --is-inside-work-tree 2>/dev/null') =~ 'true'

  if l:is_git_repo
    " Fetch the current branch name
    let l:branch_name = substitute(system('git rev-parse --abbrev-ref HEAD'), '\n', '', '')

    " Fetch the latest commit hash and message
    let l:commit_hash = substitute(system('git log -1 --pretty=format:"%h"'), '\n', '', '')
    let l:commit_message = substitute(system('git log -1 --pretty=format:"%s"'), '\n', '', '')

    " Add Git details to the buffer
    call setline(5, '✔ Repository: Yes')
    call setline(6, '➤ Branch: ' . l:branch_name)
    call setline(7, '➤ Latest Commit: ' . l:commit_hash)
    call setline(8, '➤ Message: ' . l:commit_message)

    " Get the remote URL
    let l:git_remote_url = system('git remote get-url origin 2>/dev/null')
    " Remove trailing newline
    let l:git_remote_url = substitute(l:git_remote_url, '\n$', '', '')
    call setline(9, '')

    " Extract owner and repo from the URL
    if l:git_remote_url =~ 'github\.com[:/]'
      let l:owner_repo = matchstr(l:git_remote_url, 'github\.com[:/]\zs[^/]*\/[^/]*')
      let [g:github_actions_owner, g:github_actions_repo] = split(l:owner_repo, '/')
    else
      echo "Not a GitHub repository"
      let g:github_actions_owner = ''
      let g:github_actions_repo = ''
    endif


    " Fetch GitHub Actions workflows using the gh CLI
    let l:ccommand = 'gh api repos/' . g:github_actions_owner . '/' . g:github_actions_repo . '/actions/workflows --jq ".workflows" 2>/dev/null'
    let l:workflows_json = system(l:ccommand)

    " Check if the gh CLI command succeeded
    if v:shell_error == 0
      " Parse the JSON into a Vim dictionary
      let l:workflows = json_decode(l:workflows_json)

      " Add workflows to the buffer
      call setline(10, 'Workflows:')
      let l:line = 11
      for l:workflow in l:workflows
        let l:cleaned_workflow_path = substitute(l:workflow.path, '\v(\.github/workflows/|dynamic/)', '', '')
        "call setline(l:line, '- ' . l:workflow.name . ' (ID: ' . l:workflow.id . ')')
        call setline(l:line, '    - ' . l:workflow.name . ' (PATH: ' . l:cleaned_workflow_path . ')')
        let l:line += 1
      endfor
    else
      " Add an error message if the gh CLI command failed
      call setline(10, 'Error: Unable to fetch workflows. Ensure the gh CLI is authenticated.')
    endif
  else
    " Add a message indicating this is not a Git repository
    call setline(5, 'Repository: No')
    call setline(6, 'This directory is not a Git repository.')
  endif

  setlocal filetype=github_actions

  " Move the cursor to the end of the buffer
  normal! G
endfunction

function! github_actions#open_workflow() abort
  " Get the current line
  let l:line = getline('.')

  " Check if the line contains a workflow
  if l:line =~ '^    - .* (PATH: \zs\S\+)'
    let l:workflow_path = matchstr(l:line, 'PATH: \zs[^ )]\+')

    " Construct the URL for the workflow
    if l:workflow_path != ''
      let l:url = 'https://github.com/' . g:github_actions_owner . '/' . g:github_actions_repo . '/actions/workflows/' . l:workflow_path
      " Open the URL in the default browser
      call system('open ' . shellescape(l:url))
    else
      echo "Error: Unable to determine repository or workflow ID."
    endif
  else
    echo "Error: Not a valid workflow line."
  endif
endfunction

function! github_actions#toggle() abort
  " Check if the buffer already exists
  let l:bufnr = bufexists('GitHub Actions')

  if l:bufnr
    " If the buffer exists, check if it's visible in any window
    let l:bufwinid = bufwinnr('GitHub Actions')

    if l:bufwinid > 0
      " If the buffer is visible, close the window
      execute l:bufwinid . 'close'
    else
      " If the buffer exists but is not visible, open it
      execute 'buffer ' . l:bufnr
    endif
  else
    " If the buffer doesn't exist, call GithubActions to create it
    execute 'GithubActions'
  endif
endfunction

" vim:set ft=vim sw=2 sts=2 et:
