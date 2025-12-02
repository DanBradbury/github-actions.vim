vim9script
scriptencoding utf-8

var current_selection = 1
var popup_content = []

export def HandleEnter(line: string): void
  if line =~ '(PATH: \zs\S\+)'
    OpenWorkflow(line)
  elseif line =~ '(Run ID: \zs\d\+)'
    OpenWorkflowRun(line)
  else
    echoerr "Error: Not a valid line for expansion."
  endif
enddef

export def FilterPopup(winid: number, key: string): number
  # TODO: add open in github + workflow file support
  if key ==? 'j' || key ==? "\<Down>" || key ==? "\<Left>" || key ==? "\<Right>"
    current_selection = (current_selection + 1) % len(popup_content)
  elseif key ==? 'k' || key ==? "\<Up>"
    current_selection = (current_selection - 1 + len(popup_content)) % len(popup_content)
  elseif key ==? "\<CR>" || key ==? "\<Space>"
    var selected_model: string = popup_content[current_selection]
    HandleEnter(selected_model)
  elseif key ==? "\<Esc>" || key ==? 'q'
    popup_close(winid)
    redraw!
    e!
    return 1
  endif

  popup_settext(winid, popup_content)
  prop_add(current_selection + 1, 1, {
    'type': 'highlight',
    'length': 60,
    'bufnr': winbufnr(winid)
  })
  redraw

  return 1
enddef

export def ViewWorkflows(): void
  popup_content = []
  g:github_actions_last_window = win_getid()

  var is_git_repo: bool = system('git rev-parse --is-inside-work-tree 2>/dev/null') =~ 'true'

  if is_git_repo
    var branch_name: string = substitute(system('git rev-parse --abbrev-ref HEAD'), '\n', '', '')
    var commit_hash: string = substitute(system('git log -1 --pretty=format:"%h"'), '\n', '', '')
    var commit_message: string = substitute(system('git log -1 --pretty=format:"%s"'), '\n', '', '')
    var remote_url: string = substitute(system('git config --get remote.origin.url'), '\n', '', '')
    remote_url = substitute(remote_url, '.*github.com[:/]', '', '')

    popup_content->add($'✔ Repository: {remote_url}')
    popup_content->add($'➤ Branch:     {branch_name}')
    popup_content->add($'➤ Commit:     {commit_hash}')
    popup_content->add($'➤ Message:    {commit_message}')
    popup_content->add('')

    var git_remote_url: string = system('git remote get-url origin 2>/dev/null')
    git_remote_url = substitute(git_remote_url, '\n$', '', '')

    if git_remote_url =~ 'github\.com[:/]'
      var owner_repo: string = matchstr(git_remote_url, 'github\.com[:/]\zs[^/]*\/[^/]*')
      var split_values: list<string> = split(owner_repo, '/')
      var raw_repo: string = split_values[1]
      raw_repo = substitute(raw_repo, '\.git$', '', '')
      g:github_actions_owner = split_values[0]
      g:github_actions_repo = raw_repo

    else
      echo "Not a GitHub repository"
      g:github_actions_owner = ''
      g:github_actions_repo = ''
    endif

    var workflows_json: string = system($'gh api repos/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows --jq ".workflows" 2>/dev/null')

    if v:shell_error == 0
      var workflows: list<dict<any>> = json_decode(workflows_json)
      popup_content->add('Workflows:')

      for workflow in workflows
        var cleaned_workflow_path: string = substitute(workflow.path, '\v(\.github/workflows/|dynamic/)', '', '')
        popup_content->add($'    - {workflow.name} (PATH: {cleaned_workflow_path})')
      endfor
    else
      popup_content->add('Error: Unable to fetch workflows. Ensure the gh CLI is authenticated.')
    endif
  else
    popup_content->add('Repository: No')
    popup_content->add('This directory is not a Git repository.')
  endif

  var options = {
    'border': [1, 1, 1, 1],
    'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    'borderhighlight': ['DiffAdd'],
    'padding': [1, 1, 1, 1],
    'pos': 'center',
    'minwidth': 50,
    'mapping': 0,
    'title': ' GitHub Actions',
    'filter': FilterPopup,
  }
  var popup_id = popup_create(popup_content, options)
  var bufnr = winbufnr(popup_id)
  execute 'highlight! GithubActionsCurrentSelection cterm=underline gui=bold'
  prop_type_add('highlight', {'highlight': 'GithubActionsCurrentSelection', 'bufnr': winbufnr(popup_id)})
enddef

def CheckCollapse(initial_search: string, while_check: string): bool
  var next_line: string = ''
  if len(popup_content) > current_selection + 1
    next_line = popup_content[current_selection + 1]
  endif

  if next_line =~# initial_search
    var line_content: string = popup_content[current_selection]
    var l = current_selection
    var matches = true
    while (l + 1 <= len(popup_content) - 1) && popup_content[l + 1] =~# while_check
      remove(popup_content, l + 1)
    endwhile

    return true
  endif
  return false
enddef

export def OpenWorkflow(line: string): void
  if line =~# '(PATH: \zs\S\+)'
    var workflow_path: string = matchstr(line, 'PATH: \zs[^ )]\+')

    if CheckCollapse('Run ID:', 'Run ID:\|Job:\|Step:')
      return
    endif

    if workflow_path !=# ''
      var api_url: string = printf(
        'repos/%s/%s/actions/workflows/%s/runs',
        g:github_actions_owner,
        g:github_actions_repo,
        workflow_path
      )

      var runs_json: string = system('gh api ' .. api_url .. ' --jq ".workflow_runs" 2>/dev/null')

      if v:shell_error == 0
        var runs: list<any> = json_decode(runs_json)

        for run in runs
          var run_id: string = string(run['id'])
          var run_status: string = string(run['status'])
          var run_conclusion: string = string(run['conclusion'])
          var run_url: string = string(run['html_url'])
          var run_number: string = string(run['run_number'])


          var emoji: string = ''
          if match(run_conclusion, 'success') != -1
            emoji = '✅'
          elseif match(run_conclusion, 'failure') != -1
            emoji = '❌'
          else
            emoji = '⚠️'  # For other statuses like 'neutral', 'cancelled', etc.
          endif

          # Format the run details with the emoji and parentheses for run_id
          var run_details: string = printf(
            '        ➤ %s #%s (Run ID: %s)',
            emoji,
            run_number,
            run_id
          )

          popup_content->add(run_details)
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

export def OpenWorkflowRun(line: string): void
  if line =~ '(Run ID: \zs\d\+)'
    var run_id: string = matchstr(line, 'Run ID: \zs\d\+')

    if CheckCollapse('Job:', 'Job:\|Step:')
      return
    endif

    var api_url: string = printf(
      'repos/%s/%s/actions/runs/%s/jobs',
      g:github_actions_owner,
      g:github_actions_repo,
      run_id
    )

    var jobs_json: string = system('gh api ' .. api_url .. ' --jq ".jobs" 2>/dev/null')

    if v:shell_error == 0
      var jobs: list<any> = json_decode(jobs_json)
      var insert_location = current_selection + 1

      for job in jobs
        var job_name: string = string(job['name'])
        var job_status: string = string(job['status'])
        var job_conclusion: string = string(job['conclusion'])
        var job_started_at: string = string(job['started_at'])

        var emoji: string = ''
        if match(job_conclusion, 'success') != -1
          emoji = '✅'
        elseif match(job_conclusion, 'failure') != -1
          emoji = '❌'
        else
          emoji = '⚠️'
        endif

        var job_details: string = printf(
          '            ➤ %s Job: %s',
          emoji,
          job_name
        )

        insert(popup_content, job_details, insert_location)
        insert_location += 1

        var steps: list<any> = job['steps']
        for step in steps
          var step_name: string = string(step['name'])
          var step_status: string = string(step['status'])
          var step_conclusion: string = string(step['conclusion'])

          if match(step_conclusion, 'success') != -1
            emoji = '✅'
          elseif match(step_conclusion, 'failure') != -1
            emoji = '❌'
          else
            emoji = '⚠️'
          endif

          var step_details: string = printf(
            '                ➤ %s Step: %s',
            emoji,
            step_name
          )

          insert(popup_content, step_details, insert_location)
          insert_location += 1
        endfor
      endfor
    else
      echoerr "Error: Unable to fetch jobs for Run ID: " .. run_id
    endif
  else
    echoerr "Error: Not a valid Run ID line."
  endif
enddef


export def OpenInGithub(): void
  var line: string = getline('.')
  if line =~# '(PATH: \zs\S\+)'
    var workflow_path: string = matchstr(line, 'PATH: \zs[^ )]\+')

    if workflow_path != ''
      var url: string = $'https://github.com/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows/{workflow_path}'
      call system($'open {shellescape(url)}')
    else
      echo "Error: Unable to determine repository or workflow ID."
    endif
  elseif line =~# '(Run ID: \zs\d\+)'
    var run_id: string = matchstr(line, '(Run ID: \zs\d\+')
    if run_id != ''
      var url: string = $'https://github.com/{g:github_actions_owner}/{g:github_actions_repo}/actions/runs/{run_id}'
      call system($'open {shellescape(url)}')
    endif
  endif
enddef

export def OpenWorkflowFile(): void
  var line: string = getline('.')
  if line =~# '(PATH: \zs\S\+)'
    var workflow_path: string = matchstr(line, 'PATH: \zs[^ )]\+')
    var file: string = $'.github/workflows/{workflow_path}'
    if workflow_path != ''
      win_gotoid(g:github_actions_last_window)
      execute $'edit {file}'
      return
    endif
  else
    for lnum in range(line('.') - 1, 1, -1)
      var buffer_line: string = getline(lnum)
      if buffer_line =~# '(PATH: \zs\S\+)'
        var workflow_path: string = matchstr(buffer_line, 'PATH: \zs[^ )]\+')
        win_gotoid(g:github_actions_last_window)
        execute $'edit .github/workflows/{workflow_path}'
        return
      endif
    endfor
  endif
enddef
