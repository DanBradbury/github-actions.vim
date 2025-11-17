# GitHub Actions for Vim

`github-actions.vim` provides a convenient way to view and interact with GitHub Actions directly in vim.

![](https://github.com/user-attachments/assets/ed1c020b-3738-4921-abaa-70a466c77741)

---

## Requirements

- Vim 9.0+ or Neovim.
- The `gh` CLI tool must be installed and authenticated. You can install it from [GitHub CLI](https://cli.github.com/).

---

## Features

- Lists GitHub Actions workflows for the current repository.
- Allows you to open workflow details in your default browser.
- Toggle the GitHub Actions sidebar on and off.

---

## Usage

### Commands

- `:GithubActions`
  Opens the GitHub Actions sidebar buffer.

- `:GithubActionsToggle`
  Toggles the visibility of the GitHub Actions sidebar buffer.

### Keybindings

- Press `<CR>` (Enter) on a workflow line to open the workflow in your default browser.
- Press `gf` in the actions window to open the the workflow file in the last active window.

---

## Configuration

You can customize the behavior of the plugin using the following global variables:

### `g:github_actions_window_side`

Specifies the side of the window where the GitHub Actions sidebar will open.
Possible values: `'left'` (default) or `'right'`.

Example:

```vim
let g:github_actions_window_side = 'right'
```

### `g:github_actions_window_size`

Specifies the width of the GitHub Actions sidebar buffer.
Default: `50`.

Example:

```vim
let g:github_actions_window_size = 40
```

---

## Troubleshooting

- **Error: Unable to fetch workflows. Ensure the gh CLI is authenticated.**
  Ensure that the `gh` CLI is installed and authenticated with your GitHub account.

- **Not a GitHub repository**
  The plugin only works in directories that are Git repositories hosted on GitHub.

---

## License

This plugin is open-source and available under the MIT License.

---

Enjoy using `github-actions.vim`! 🎉
