<#
.SYNOPSIS
    Adds (or removes) a "Claude Code" profile in Windows Terminal.

.DESCRIPTION
    Uses a Windows Terminal JSON fragment rather than editing settings.json,
    so your existing configuration is never touched. Works for the Store,
    Preview and unpackaged builds of Windows Terminal.

    By default Claude Code runs inside PowerShell with -NoExit, so the tab
    stays open as a normal shell after you quit Claude. Use -Direct to run
    claude.exe on its own (the tab closes when Claude exits).

.EXAMPLE
    .\Add-ClaudeCodeTerminalProfile.ps1

.EXAMPLE
    .\Add-ClaudeCodeTerminalProfile.ps1 -StartingDirectory "C:\Code" -Direct

.EXAMPLE
    .\Add-ClaudeCodeTerminalProfile.ps1 -Remove

.EXAMPLE
    # Run straight from GitHub with default options
    irm https://raw.githubusercontent.com/adinmaccabee/claude-code-terminal-profile/main/Add-ClaudeCodeTerminalProfile.ps1 | iex

.EXAMPLE
    # Run straight from GitHub with options
    & ([scriptblock]::Create((irm https://raw.githubusercontent.com/adinmaccabee/claude-code-terminal-profile/main/Add-ClaudeCodeTerminalProfile.ps1))) -Direct

.LINK
    https://github.com/adinmaccabee/claude-code-terminal-profile
#>
[CmdletBinding()]
param(
    [string]$Name = 'Claude Code',
    [string]$StartingDirectory = '%USERPROFILE%',
    [string]$Icon,                 # path to an .ico/.png; defaults to an emoji
    [switch]$Direct,               # launch claude.exe directly, no wrapping shell
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$fragmentDir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\ClaudeCode'
$fragmentFile = Join-Path $fragmentDir 'claude-code.json'
# Fixed GUID so re-running the script updates the same profile instead of adding duplicates
$profileGuid  = '{6f1c2a7e-3b4d-4c8a-9e21-c1a0de5c0de0}'

if ($Remove) {
    if (Test-Path $fragmentDir) {
        Remove-Item $fragmentDir -Recurse -Force
        Write-Host "Removed the '$Name' profile. Restart Windows Terminal to apply." -ForegroundColor Green
    } else {
        Write-Host "No Claude Code profile fragment found; nothing to remove."
    }
    return
}

# --- Locate Claude Code ---------------------------------------------------
$claudePath = $null
$cmd = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cmd) {
    $claudePath = $cmd.Source
} else {
    # Default location for the native installer
    $candidate = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path $candidate) { $claudePath = $candidate }
}
if (-not $claudePath) {
    throw "Couldn't find Claude Code. Install it first, or make sure 'claude' is on your PATH."
}
Write-Host "Found Claude Code at: $claudePath"

# --- Build the command line -----------------------------------------------
if ($Direct) {
    if ([IO.Path]::GetExtension($claudePath) -ne '.exe') {
        throw "-Direct needs claude.exe, but found '$claudePath' (likely an npm shim). Run without -Direct."
    }
    $commandline = "`"$claudePath`""
} else {
    $shellExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    $commandline = "$shellExe -NoLogo -NoExit -Command `"& '$claudePath'`""
}

# --- Write the fragment ---------------------------------------------------
if (-not $Icon) { $Icon = [char]::ConvertFromUtf32(0x2733) }  # ✳ emoji

$wtProfile = [ordered]@{
    guid              = $profileGuid
    name              = $Name
    commandline       = $commandline
    startingDirectory = $StartingDirectory
    icon              = $Icon
    hidden            = $false
}
$fragment = @{ profiles = @($wtProfile) }

New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null
$json = $fragment | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($fragmentFile, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Added the '$Name' profile." -ForegroundColor Green
Write-Host "Fragment: $fragmentFile"
Write-Host "Restart Windows Terminal, then pick '$Name' from the new-tab dropdown."
