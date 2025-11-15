# GitHub Actions Vim Plugin

`github-actions.vim` is a Vim plugin that provides a convenient way to view and interact with GitHub Actions workflows directly from your Vim editor. It displays repository details, branch information, the latest commit, and a list of workflows in a sidebar buffer.

---

## Features

- Displays repository details, including branch name, latest commit hash, and commit message.
- Lists GitHub Actions workflows for the current repository.
- Allows you to open workflow details in your default browser.
- Toggle the GitHub Actions sidebar on and off.
- Syntax highlighting for better readability.

---

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

Add the following line to your `.vimrc` or `init.vim`:

```vim
Plug 'yourusername/github-actions.vim'
```

Then, run the following command in Vim:

```vim
:PlugInstall
```

---

## Usage

### Commands

- `:GithubActions`
  Opens the GitHub Actions sidebar buffer.

- `:GithubActionsToggle`
  Toggles the visibility of the GitHub Actions sidebar buffer.

### Keybindings

- Press `<CR>` (Enter) on a workflow line in the sidebar to open the workflow in your default browser.

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

## Requirements

- Vim 8.0+ or Neovim.
- The `gh` CLI tool must be installed and authenticated. You can install it from [GitHub CLI](https://cli.github.com/).

---

## Syntax Highlighting

The plugin provides syntax highlighting for the GitHub Actions sidebar:

- **Title**: Highlighted in yellow.
- **Repository Details**: Highlighted in cyan.
- **Workflows**: Highlighted in green.
- **Error Messages**: Highlighted in red.

---

## Example Workflow

1. Open a Git repository in Vim.
2. Run `:GithubActions` to open the sidebar.
3. View repository details and workflows.
4. Press `<CR>` on a workflow to open it in your browser.

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
