# Claude Code profile for Windows Terminal

A PowerShell script that adds a **Claude Code** profile to Windows Terminal. After you run it, you can open Claude Code from the new-tab dropdown.

The script uses a [Windows Terminal JSON fragment](https://learn.microsoft.com/windows/terminal/json-fragment-extensions) instead of editing `settings.json`, so your existing configuration is never modified. Removing the profile is a single command.

## Requirements

- Windows 10 or 11 with [Windows Terminal](https://aka.ms/terminal) (Store, Preview or unpackaged build)
- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) installed, with `claude` on your PATH or installed in the native installer's default location (`%USERPROFILE%\.local\bin`)
- Windows PowerShell 5.1 or PowerShell 7+

## Quick install

To install with the default options, run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/adinmaccabee/claude-code-terminal-profile/main/Add-ClaudeCodeTerminalProfile.ps1 | iex
```

To pass options when installing this way:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/adinmaccabee/claude-code-terminal-profile/main/Add-ClaudeCodeTerminalProfile.ps1))) -StartingDirectory "C:\Code"
```

After either command, restart Windows Terminal.

> Piping a script from the internet into `iex` runs it immediately. You should [read the script](Add-ClaudeCodeTerminalProfile.ps1) before you run it.

## Install from a clone

```powershell
git clone https://github.com/adinmaccabee/claude-code-terminal-profile.git
cd claude-code-terminal-profile
.\Add-ClaudeCodeTerminalProfile.ps1
```

If PowerShell blocks the script, run it with `-ExecutionPolicy Bypass`:

```powershell
powershell -ExecutionPolicy Bypass -File .\Add-ClaudeCodeTerminalProfile.ps1
```

## Options

| Parameter | Default | Description |
|---|---|---|
| `-Name` | `Claude Code` | Profile name shown in Windows Terminal |
| `-StartingDirectory` | `%USERPROFILE%` | Folder the tab opens in |
| `-Icon` | ✳ emoji | Path to an `.ico` or `.png` file |
| `-Direct` | off | Runs `claude.exe` on its own, so the tab closes when Claude exits. Without this option, Claude runs inside PowerShell and the tab stays open after you exit. |
| `-SkipClaudeSettings` | off | Leaves `%USERPROFILE%\.claude\settings.json` untouched |
| `-Remove` | — | Removes the profile and the `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` setting |

## Uninstall

```powershell
.\Add-ClaudeCodeTerminalProfile.ps1 -Remove
```

You can also delete this folder: `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\ClaudeCode`.

## How it works

The script writes `claude-code.json` to the following folder:

```
%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\ClaudeCode\
```

Windows Terminal loads this file at startup. The profile has a fixed GUID, so running the script again updates the existing profile instead of adding a duplicate.

The script also adds this to the `env` section of your Claude Code user settings at `%USERPROFILE%\.claude\settings.json`:

```json
"env": {
  "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
}
```

This stops Claude Code from changing the tab title, so the tab keeps the profile name. Your other settings are kept, and the previous file is saved as `settings.json.bak`. If the file isn't valid JSON, the script leaves it unchanged and prints a warning.

## License

[MIT](LICENSE)
