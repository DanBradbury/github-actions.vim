vim9script
scriptencoding utf-8

highlight Title ctermfg=Yellow guifg=#FFD700
highlight Identifier ctermfg=Cyan guifg=#00FFFF
highlight Function ctermfg=Green guifg=#00FF00
highlight GithubActionsCurrentSelection cterm=underline gui=underline guifg=green

# Match the header
syntax match Title /^\(===\+\|GitHub Actions\)$/

# Match repository details
syntax match Identifier /^✔ Repository:.*/
syntax match Identifier /^➤ Branch:.*/
syntax match Identifier /^➤ Commit:.*/
syntax match Identifier /^➤ Message:.*/

# Match workflows
syntax match Function /^    - .* (PATH:.*)$/

# Match error messages
syntax match Error /^Error:.*/
