scriptencoding utf-8

def github_actions#view_workflows()
  # Check if the buffer already exists
  for lbuf in range(1, bufnr('$'))
    if bufname(lbuf) ==# 'GitHub Actions'
      # If the buffer exists, switch to it
      execute $'buffer {lbuf}'
      return
    endif
  endfor

  # Determine the side to open the buffer
  if !exists('g:github_actions_window_side')
    g:github_actions_window_side = 'left' # Default to left
  endif

  if g:github_actions_window_side ==# 'left'
    execute 'topleft vnew'
  elseif g:github_actions_window_side ==# 'right'
    execute 'botright vnew'
  else
    echoerr "Invalid value for g:github_actions_window_side. Use 'left' or 'right'."
    return
  endif

  # Set the buffer options for the sidebar
  execute 'file GitHub Actions'
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal nobuflisted
  setlocal noswapfile
  setlocal nonumber
  setlocal norelativenumber
  setlocal foldcolumn=0
  setlocal signcolumn=no

  # Set the width of the sidebar
  if !exists('g:github_actions_window_size')
    g:github_actions_window_size = '50'
  endif

  execute $'vertical resize {g:github_actions_window_size}'

  # Add the "GitHub Actions" header with styling
   call setline(1, '===========================')
   call setline(2, '      GitHub Actions')
   call setline(3, '===========================')
   call setline(4, '') # Add a blank line

  # Check if the current directory is a Git repository
  var is_git_repo = system('git rev-parse --is-inside-work-tree 2>/dev/null') =~ 'true'

  if is_git_repo
    # Fetch the current branch name
    var branch_name = substitute(system('git rev-parse --abbrev-ref HEAD'), '\n', '', '')

    # Fetch the latest commit hash and message
    var commit_hash = substitute(system('git log -1 --pretty=format:"%h"'), '\n', '', '')
    var commit_message = substitute(system('git log -1 --pretty=format:"%s"'), '\n', '', '')

    # Add Git details to the buffer
    call setline(5, '✔ Repository: Yes')
    call setline(6, $'➤ Branch: {branch_name}')
    call setline(7, $'➤ Latest Commit: {commit_hash}')
    call setline(8, $'➤ Message: {commit_message}')

    # Get the remote URL
    var git_remote_url = system('git remote get-url origin 2>/dev/null')
    # Remove trailing newline
    git_remote_url = substitute(git_remote_url, '\n$', '', '')
    call setline(9, '')

    # Extract owner and repo from the URL
    if git_remote_url =~ 'github\.com[:/]'
      var owner_repo = matchstr(git_remote_url, 'github\.com[:/]\zs[^/]*\/[^/]*')
      [g:github_actions_owner, g:github_actions_repo] = split(owner_repo, '/')
    else
      echo "Not a GitHub repository"
      g:github_actions_owner = ''
      g:github_actions_repo = ''
    endif


    # Fetch GitHub Actions workflows using the gh CLI
    var workflows_json = system($'gh api repos/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows --jq ".workflows" 2>/dev/null')

    # Check if the gh CLI command succeeded
    if v:shell_error == 0
      # Parse the JSON into a Vim dictionary
      var workflows = json_decode(workflows_json)

      # Add workflows to the buffer
      call setline(10, 'Workflows:')
      var line = 11
      for workflow in workflows
        var cleaned_workflow_path = substitute(workflow.path, '\v(\.github/workflows/|dynamic/)', '', '')
        call setline(line, $'    - {workflow.name} (PATH: {cleaned_workflow_path})')
        line += 1
      endfor
    else
      # Add an error message if the gh CLI command failed
      call setline(10, 'Error: Unable to fetch workflows. Ensure the gh CLI is authenticated.')
    endif
  else
    # Add a message indicating this is not a Git repository
    call setline(5, 'Repository: No')
    call setline(6, 'This directory is not a Git repository.')
  endif

  setlocal filetype=github_actions

  # Move the cursor to the end of the buffer
  normal! G
enddef

def github_actions#open_workflow()
  # Get the current line
  var line = getline('.')

  # Check if the line contains a workflow
  if line =~ '^    - .* (PATH: \zs\S\+)'
    var workflow_path = matchstr(line, 'PATH: \zs[^ )]\+')

    # Construct the URL for the workflow
    if workflow_path != ''
      var url = $'https://github.com/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows/{workflow_path}'
      # Open the URL in the default browser
      call system($'open {shellescape(url)}')
    else
      echo "Error: Unable to determine repository or workflow ID."
    endif
  else
    echo "Error: Not a valid workflow line."
  endif
enddef

def github_actions#toggle()
  # Check if the buffer already exists
  var bufnr = bufexists('GitHub Actions')

  if bufnr
    # If the buffer exists, check if it's visible in any window
    var bufwinid = bufwinnr('GitHub Actions')

    if bufwinid > 0
      # If the buffer is visible, close the window
      execute $'{bufwinid} close'
    else
      # If the buffer exists but is not visible, open it
      execute $'buffer {bufnr}'
    endif
  else
    # If the buffer doesn't exist, call GithubActions to create it
    execute 'GithubActions'
  endif
enddef

" vim:set ft=vim sw=2 sts=2 et:
