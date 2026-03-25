# w-shell

- It crashed when run as 'w' outside a git repository. Should show the help message.
  - Same for --help and --version outside a git repo.

- Example .wtconfig.toml doesn't have enough options to make the capabilities clear.

- More sophisticated port handling than 1 env var per command? Hard to run any command that starts both servers. Consider a command with substitution strings like the template, each one an incrementing number?

- Running 'w serve' doesn't give me the output of the serve command, which makes cancellation difficult, especially when 'w stop' didn't work right afterwards.

- It's difficult to stop the commands, even when the port does work properly. It will say a PID has been stopped but the page still loads and it needs to be traced/killed with 'lsof

*IDEA* Perhaps `w <name>` should open a subshell at the worktree directory that has a full alternative environment configuration loaded. Then start/stop/serve wouldn't be necessary, and wtconfig.toml can specify multiple env vars. This is inspired by chezmoi, where `chezmoi cd` doesn't technically cd, it starts a subshell.