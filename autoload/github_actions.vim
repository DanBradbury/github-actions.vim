vim9script
scriptencoding utf-8

export def ViewWorkflows()
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
   setline(1, '===========================')
   setline(2, '      GitHub Actions')
   setline(3, '===========================')
   setline(4, '') # Add a blank line

  # Check if the current directory is a Git repository
  var is_git_repo = system('git rev-parse --is-inside-work-tree 2>/dev/null') =~ 'true'

  if is_git_repo
    # Fetch the current branch name
    var branch_name = substitute(system('git rev-parse --abbrev-ref HEAD'), '\n', '', '')

    # Fetch the latest commit hash and message
    var commit_hash = substitute(system('git log -1 --pretty=format:"%h"'), '\n', '', '')
    var commit_message = substitute(system('git log -1 --pretty=format:"%s"'), '\n', '', '')

    # Add Git details to the buffer
    setline(5, '✔ Repository: Yes')
    setline(6, $'➤ Branch: {branch_name}')
    setline(7, $'➤ Latest Commit: {commit_hash}')
    setline(8, $'➤ Message: {commit_message}')

    # Get the remote URL
    var git_remote_url = system('git remote get-url origin 2>/dev/null')
    # Remove trailing newline
    git_remote_url = substitute(git_remote_url, '\n$', '', '')
    setline(9, '')

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
      setline(10, 'Workflows:')
      var line = 11
      for workflow in workflows
        var cleaned_workflow_path = substitute(workflow.path, '\v(\.github/workflows/|dynamic/)', '', '')
        setline(line, $'    - {workflow.name} (PATH: {cleaned_workflow_path})')
        line += 1
      endfor
    else
      # Add an error message if the gh CLI command failed
      setline(10, 'Error: Unable to fetch workflows. Ensure the gh CLI is authenticated.')
    endif
  else
    # Add a message indicating this is not a Git repository
    setline(5, 'Repository: No')
    setline(6, 'This directory is not a Git repository.')
  endif

  setlocal filetype=github_actions

  # Move the cursor to the end of the buffer
  normal! G
enddef

export def OpenWorkflow(): void
  # Get the current line
  var line: string = getline('.')

  # Check if the line contains a workflow
  if line =~# '^    - .* (PATH: \zs\S\+)'
    var workflow_path = matchstr(line, 'PATH: \zs[^ )]\+')

    # Check if the workflow is already expanded
    var next_line = getline(line('.') + 1)
    if next_line =~# '^        ➤ Run ID:'
      # Collapse the expanded workflow
      var current_line: number = line('.')
      while getline(current_line + 1) =~# '^        ➤ Run ID:'
        deletebufline('%', current_line + 1)
      endwhile
      return
    endif

    # Construct the API URL for the workflow runs
    if workflow_path !=# ''
      var api_url: string = printf(
            \ 'repos/%s/%s/actions/workflows/%s/runs',
            \ g:github_actions_owner,
            \ g:github_actions_repo,
            \ workflow_path
            \ )

      # Fetch the recent runs using the GitHub CLI
      var runs_json: string = system('gh api ' .. api_url .. ' --jq ".workflow_runs" 2>/dev/null')

      # Check if the gh CLI command succeeded
      if v:shell_error == 0
        # Parse the JSON into a Vim dictionary
        var runs = json_decode(runs_json)

        # Add the recent runs below the workflow
        var current_line: number = line('.')
        for run in runs
          var run_id: string = string(run['id'])
          var run_status: string = string(run['status'])
          var run_conclusion: string = string(run['conclusion'])
          var run_created_at: string = string(run['created_at'])
          var run_url: string = string(run['html_url'])

          var run_details = printf(
                \ '        ➤ Run ID: %s | Status: %s | Conclusion: %s | Created: %s',
                \ run_id,
                \ run_status,
                \ run_conclusion,
                \ run_created_at
                \ )


          # Append the run details to the buffer
          append(current_line, run_details)
          current_line += 1
        endfor
      else
        echoerr "Error: Unable to fetch workflow runs. Ensure the gh CLI is authenticated."
      endif
    else
      echoerr "Error: Unable to determine repository or workflow path."
    endif
  else
    echoerr "Error: Not a valid workflow line."
  endif
enddef

export def ToggleWorkflowBuffer()
  # Check if the buffer already exists
  var bufnr = bufexists('GitHub Actions')

  if bufnr > 0
    # If the buffer exists, check if it's visible in any window
    var bufwinid = bufwinnr('GitHub Actions')

    if bufwinid > 0
      execute $':{bufwinid} wincmd c'
    else
      # If the buffer exists but is not visible, open it
      execute 'buffer ' .. bufnr
    endif
  else
    # If the buffer doesn't exist, call GithubActions to create it
    execute 'GithubActions'
  endif
enddef

export def OpenWorkflowRun(): void
  # Get the current line
  var line: string = getline('.')

  # Check if the line contains a Run ID
  if line =~# '^        ➤ Run ID: \zs\d\+'
    var run_id: string = matchstr(line, '\d\+')

    # Check if the run is already expanded
    var next_line: string = getline(line('.') + 1)
    if next_line =~# '^            ➤ Job:'
      # Collapse the expanded run
      var current_line: number = line('.')
      while getline(current_line + 1) =~# '^            ➤ Job:'
        deletebufline('%', current_line + 1)
      endwhile
      return
    endif

    # Construct the API URL for the jobs in the run
    var api_url: string = printf(
          \ 'repos/%s/%s/actions/runs/%s/jobs',
          \ g:github_actions_owner,
          \ g:github_actions_repo,
          \ run_id
          \ )

    # Fetch the jobs using the GitHub CLI
    var jobs_json: string = system('gh api ' .. api_url .. ' --jq ".jobs" 2>/dev/null')

    # Check if the gh CLI command succeeded
    if v:shell_error == 0
      # Parse the JSON into a Vim dictionary
      var jobs = json_decode(jobs_json)

      # Add the jobs below the run
      var current_line: number = line('.')
      for job in jobs
        var job_name: string = string(job['name'])
        var job_status: string = string(job['status'])
        var job_conclusion: string = string(job['conclusion'])
        var job_started_at: string = string(job['started_at'])

        # Format the job details
        var job_details: string = printf(
              \ '            ➤ Job: %s | Status: %s | Conclusion: %s | Started: %s',
              \ job_name,
              \ job_status,
              \ job_conclusion,
              \ job_started_at
              \ )

        # Append the job details to the buffer
        append(current_line, job_details)
        current_line += 1

        # Add the steps for the job
        var steps = job['steps']
        for step in steps
          var step_name: string = string(step['name'])
          var step_status: string = string(step['status'])
          var step_conclusion: string = string(step['conclusion'])

          # Format the step details
          var step_details: string = printf(
                \ '                ➤ Step: %s | Status: %s | Conclusion: %s',
                \ step_name,
                \ step_status,
                \ step_conclusion
                \ )

          # Append the step details to the buffer
          append(current_line, step_details)
          current_line += 1
        endfor
      endfor
    else
      echoerr "Error: Unable to fetch jobs for Run ID: " .. run_id
    endif
  else
    echoerr "Error: Not a valid Run ID line."
  endif
enddef

export def HandleEnter()
  # Get the current line
  var line: string = getline('.')

  # Check if the line is a workflow line
  if line =~# '^    - .* (PATH: \zs\S\+)'
    OpenWorkflow()
  # Check if the line is a Run ID line
  elseif line =~# '^        ➤ Run ID: \zs\d\+'
    OpenWorkflowRun()
  else
    echoerr "Error: Not a valid line for expansion."
  endif
enddef
