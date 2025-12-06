vim9script
scriptencoding utf-8

var current_selection = 1
var popup_content = []
var last_click_line = -1

var spinner = [
			"( ●    )",
			"(  ●   )",
			"(   ●  )",
			"(    ● )",
			"(     ●)",
			"(    ● )",
			"(   ●  )",
			"(  ●   )",
			"( ●    )",
			"(●     )"
		]
var spinner_location = 0
var loading = true
var active_popup = -1

var navigation_breadcrumbs = []
#var current_popup_content = []
var previous_popup_content = []

def OpenItem(item_num: string)
  var found_items = filter(copy(popup_content), $'v:val =~ "{item_num}"')
  HandleEnter(found_items[0])
enddef

export def HandleEnter(line: string): void
  if line =~ '(PATH: \zs\S\+)'
    OpenWorkflow(line)
  elseif line =~ '(Run ID: \zs\d\+)'
    OpenWorkflowRun(line)
  endif
enddef

def HighlightSelection(bufnr: number)
  if current_selection + 1 > len(popup_content)
    current_selection = 0
  endif
  prop_add(current_selection + 1, 1, {
    'type': 'highlight',
    'length': 100,
    'bufnr': bufnr
  })
enddef

export def FilterPopup(winid: number, key: string): number
  if key ==? 'j' || key ==? "\<Down>" || key ==? "\<Right>"
    current_selection = (current_selection + 1) % len(popup_content)
    win_execute(winid, $'call cursor({current_selection}, 0)')
  elseif key ==? 'k' || key ==? "\<Up>" || key ==? "\<Left>"
    current_selection = (current_selection - 1 + len(popup_content)) % len(popup_content)
  elseif key ==? "\<CR>" || key ==? "\<Space>"
    HandleEnter(popup_content[current_selection])
  elseif key ==? 'o'
    OpenInGithub()
  elseif key ==? 'w'
    OpenWorkflowFile(popup_content[current_selection])
  elseif key ==? "\<LeftMouse>"
    var details = getmousepos()
    if winid != details.winid
      popup_hide(winid)
    else
      var selected_line = (details.winrow - 2)
      if selected_line >= len(popup_content)
        selected_line = len(popup_content) - 1
      endif
      if selected_line >= 0
        win_execute(winid, $'call cursor({selected_line}, 0)')
        current_selection = selected_line
        # TODO: add a timing check for real double clicking feel
        if last_click_line == current_selection
          HandleEnter(popup_content[current_selection])
          # prevent triple-click behavior
          last_click_line = -1
        else
          last_click_line = current_selection
        endif

      endif
      return 0
    endif
  elseif key ==? "\<Esc>" || key ==? 'q'
    popup_close(winid)
    redraw!
    return 1
  elseif index(['1', '2', '3', '4', '5', '6', '7', '8', '9'], key) != -1
    OpenItem(key)
    return 1
  elseif key ==? "\<BS>"
    var c = copy(popup_content)
    popup_content = previous_popup_content
    previous_popup_content = c
    popup_settext(active_popup, popup_content)
    HighlightSelection(winbufnr(active_popup))
    return 1
  else
    echom key
  endif

  popup_settext(active_popup, popup_content)
  HighlightSelection(winbufnr(active_popup))
  redraw

  return 1
enddef

def RotateLoader(timer: number)
  if loading
    spinner_location += 1
    if spinner_location >= len(spinner)
      spinner_location = 0
    endif
    popup_settext(active_popup, [$'{repeat(" ", 21)}{spinner[spinner_location]}'])
    timer_start(timer, 'RotateLoader')
  endif
enddef

def DecodeWorkflowResponse(channel: channel, workflows_json: string)
  var workflows: list<dict<any>> = json_decode(workflows_json)
  popup_content->add('Workflows')
  popup_content->add('')
  var workflow_count = 1

  for workflow in workflows
    var cleaned_workflow_path: string = substitute(workflow.path, '\v(\.github/workflows/|dynamic/)', '', '')
    popup_content->add($'    {workflow_count}. {workflow.name} (PATH: {cleaned_workflow_path})')
    workflow_count += 1
  endfor
  loading = false
  popup_settext(active_popup, popup_content)
  popup_setoptions(active_popup, {'filter': FilterPopup})
  HighlightSelection(winbufnr(active_popup))
enddef

def ProcessRepoDetails(channel: channel, msg: string)
  var git_remote_url = substitute(msg, '\n$', '', '')

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
  job_start($'gh api repos/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows --jq ".workflows"', {'out_cb': 'DecodeWorkflowResponse'})
enddef

def GithubRepoCheck(channel: channel, msg: any)
  if msg =~ 'true'
    job_start('git remote get-url origin', {'out_cb': 'ProcessRepoDetails'})
  else
    popup_content->add('Repository: No')
    popup_content->add('This directory is not a Git repository.')
  endif
enddef

export def OpenPopup(): void
  loading = true
  popup_content = []
  g:github_actions_last_window = win_getid()
  # TODO: option time
  var min_width = 50

  var options = {
    'border': [1, 1, 1, 1],
    'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    'borderhighlight': ['DiffAdd'],
    'padding': [1, 1, 1, 1],
    'pos': 'center',
    'minwidth': min_width,
    'mapping': 0,
    'dragall': true,
    'title': ' GitHub Actions',
    'close': 'button',
  }
  active_popup = popup_create([$'{repeat(" ", 21)}{spinner[spinner_location]}'], options)
  job_start('git rev-parse --is-inside-work-tree', {'out_cb': 'GithubRepoCheck'})
  timer_start(80, 'RotateLoader')

  var bufnr = winbufnr(active_popup)
  execute 'highlight! GithubActionsCurrentSelection cterm=underline ctermbg=green gui=underline guifg=green guisp=green'
  prop_type_add('highlight', {'highlight': 'GithubActionsCurrentSelection', 'bufnr': winbufnr(active_popup)})
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

def ParseWorkflowRun(channel: channel, workflow_runs_json: string)
  var runs: list<any> = json_decode(workflow_runs_json)
  var insert_location = current_selection + 1

  var content = extend(copy(navigation_breadcrumbs), [''])

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
      emoji = '⚠️'
    endif

    # Format the run details with the emoji and parentheses for run_id
    var run_details = $'        ➤ {emoji} #{run_number} (Run ID: {run_id})'
    content->add(run_details)
    #insert(popup_content, run_details, insert_location)
    #insert_location += 1
  endfor
  previous_popup_content = popup_content
  popup_content = content
  popup_settext(active_popup, popup_content)
  #popup_settext(active_popup, content)
  HighlightSelection(winbufnr(active_popup))
enddef

export def OpenWorkflow(line: string): void
  navigation_breadcrumbs = []
  if line =~# '(PATH: \zs\S\+)'
    var workflow_path: string = matchstr(line, 'PATH: \zs[^ )]\+')

    if CheckCollapse('Run ID:', 'Run ID:\|Job:\|Step:')
      return
    endif

    if workflow_path !=# ''
      navigation_breadcrumbs->add(workflow_path)
      job_start($'gh api repos/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows/{workflow_path}/runs --jq ".workflow_runs"', {'out_cb': ParseWorkflowRun})
    else
      echoerr "Error: Unable to determine repository or workflow path."
    endif
  else
    echoerr "Error: Not a valid workflow line."
  endif
enddef

def ParseRunJobs(channel: channel, jobs_json: string)
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

    var job_details = $'            ➤ {emoji} Job: {job_name}'

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

      var step_details = $'                ➤ {emoji} Step: {step_name}'
      insert(popup_content, step_details, insert_location)
      insert_location += 1
    endfor
  endfor
  popup_settext(active_popup, popup_content)
  HighlightSelection(winbufnr(active_popup))
enddef

export def OpenWorkflowRun(line: string): void
  if line =~ '(Run ID: \zs\d\+)'
    var run_id: string = matchstr(line, 'Run ID: \zs\d\+')

    if CheckCollapse('Job:', 'Job:\|Step:')
      return
    endif

    var api_url = $'repos/{g:github_actions_owner}/{g:github_actions_repo}/actions/runs/{run_id}/jobs'
    job_start($'gh api {api_url} --jq ".jobs"', {'out_cb': ParseRunJobs})

  else
    echoerr "Error: Not a valid Run ID line."
  endif
enddef


export def OpenInGithub(): void
  var line = popup_content[current_selection]
  if line =~ '(PATH: \zs\S\+)'
    var workflow_path: string = matchstr(line, 'PATH: \zs[^ )]\+')

    if workflow_path != ''
      var url: string = $'https://github.com/{g:github_actions_owner}/{g:github_actions_repo}/actions/workflows/{workflow_path}'
      if has("win32")
        system($'explorer {shellescape(url)}')
      else
        system($'open {shellescape(url)}')
      endif
    else
      echo "Error: Unable to determine repository or workflow ID."
    endif
  elseif line =~# '(Run ID: \zs\d\+)'
    var run_id: string = matchstr(line, '(Run ID: \zs\d\+')
    if run_id != ''
      var url: string = $'https://github.com/{g:github_actions_owner}/{g:github_actions_repo}/actions/runs/{run_id}'
      if has("win32")
        call system($'explorer {shellescape(url)}')
      else
        call system($'open {shellescape(url)}')
      endif
    endif
  endif
enddef

export def OpenWorkflowFile(line: string): void
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
