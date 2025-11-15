highlight Title ctermfg=Yellow guifg=#FFD700
highlight Identifier ctermfg=Cyan guifg=#00FFFF
highlight Function ctermfg=Green guifg=#00FF00

" Match the header
syntax match Title /^\(===\+\|GitHub Actions\)$/

" Match repository details
syntax match Identifier /^✔ Repository:.*/
syntax match Identifier /^➤ Branch:.*/
syntax match Identifier /^➤ Latest Commit:.*/
syntax match Identifier /^➤ Message:.*/

" Match workflows
syntax match Function /^    - .* (PATH:.*)$/

" Match error messages
syntax match Error /^Error:.*/

