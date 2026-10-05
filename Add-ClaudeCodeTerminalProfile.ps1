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

    Running the script again uninstalls the existing profile first and then
    installs it fresh, so changes such as a new icon always take effect.

    It also sets CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 in the "env" section of
    %USERPROFILE%\.claude\settings.json, so Claude Code doesn't overwrite the
    tab title. Existing settings are kept and the old file is saved as
    settings.json.bak. Use -SkipClaudeSettings to leave that file alone.

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
    [string]$Icon,                 # path to your own .ico/.png; overrides -IconUrl
    [string]$IconUrl = 'https://uxwing.com/wp-content/themes/uxwing/download/brands-and-social-media/claude-code-icon.png',
    [switch]$Direct,               # launch claude.exe directly, no wrapping shell
    [switch]$SkipClaudeSettings,   # don't touch ~/.claude/settings.json
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$fragmentDir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\ClaudeCode'
$fragmentFile = Join-Path $fragmentDir 'claude-code.json'
# Fixed GUID so re-running the script updates the same profile instead of adding duplicates
$profileGuid  = '{6f1c2a7e-3b4d-4c8a-9e21-c1a0de5c0de0}'

# Claude Code user settings: stop Claude overwriting the tab title
$claudeSettingsFile = Join-Path $env:USERPROFILE '.claude\settings.json'
$envVarName         = 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE'
$utf8NoBom          = New-Object System.Text.UTF8Encoding($false)

# Reads ~/.claude/settings.json, or returns $null if it exists but isn't valid JSON
$readClaudeSettings = {
    if (-not (Test-Path $claudeSettingsFile)) { return [pscustomobject]@{} }
    $raw = [IO.File]::ReadAllText($claudeSettingsFile)
    if (-not $raw.Trim()) { return [pscustomobject]@{} }
    try { return ($raw | ConvertFrom-Json) }
    catch {
        Write-Warning "Couldn't parse $claudeSettingsFile, so it was left unchanged. Add `"env`": { `"$envVarName`": `"1`" } yourself."
        return $null
    }
}

$writeClaudeSettings = {
    param($Settings)
    $dir = Split-Path $claudeSettingsFile
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    if (Test-Path $claudeSettingsFile) { Copy-Item $claudeSettingsFile "$claudeSettingsFile.bak" -Force }
    [IO.File]::WriteAllText($claudeSettingsFile, ($Settings | ConvertTo-Json -Depth 100), $utf8NoBom)
}

# Deletes the fragment folder: the profile and its downloaded icon.
# Returns $true if there was anything to delete.
$removeFragment = {
    if (-not (Test-Path $fragmentDir)) { return $false }
    Remove-Item $fragmentDir -Recurse -Force
    return $true
}

# Windows Terminal's own settings.json can hold an "icon" for this profile
# (for example if it was changed in the Settings UI). That always wins over
# the fragment, so warn about it rather than silently "not working".
$warnAboutIconOverrides = {
    $candidates = @(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    $packages = Join-Path $env:LOCALAPPDATA 'Packages'
    if (Test-Path $packages) {
        $candidates += Get-ChildItem $packages -Directory -Filter 'Microsoft.WindowsTerminal*' -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'LocalState\settings.json' }
    }
    foreach ($file in $candidates) {
        if (-not (Test-Path $file)) { continue }
        try { $wt = [IO.File]::ReadAllText($file) | ConvertFrom-Json } catch { continue }  # 5.1 can't read comments
        $list = if ($wt.profiles.PSObject.Properties['list']) { $wt.profiles.list } else { $wt.profiles }
        $match = @($list) | Where-Object { $_.guid -eq $profileGuid -and $_.PSObject.Properties['icon'] }
        if ($match) {
            Write-Warning "$file sets its own icon for '$Name', which overrides this script's icon. Remove the `"icon`" line from that profile (or reset it in Settings) to use the new one."
        }
    }
}

if ($Remove) {
    if (& $removeFragment) {
        Write-Host "Removed the '$Name' profile. Restart Windows Terminal to apply." -ForegroundColor Green
    } else {
        Write-Host "No Claude Code profile fragment found; nothing to remove."
    }

    if (-not $SkipClaudeSettings -and (Test-Path $claudeSettingsFile)) {
        $settings = & $readClaudeSettings
        if ($settings -and $settings.PSObject.Properties['env'] -and $settings.env.PSObject.Properties[$envVarName]) {
            $settings.env.PSObject.Properties.Remove($envVarName)
            if (-not @($settings.env.PSObject.Properties).Count) { $settings.PSObject.Properties.Remove('env') }
            & $writeClaudeSettings $settings
            Write-Host "Removed $envVarName from $claudeSettingsFile"
        }
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

# --- Uninstall any existing profile, then install fresh ------------------
if (& $removeFragment) {
    Write-Host "Removed the existing '$Name' profile; reinstalling."
}
New-Item -ItemType Directory -Path $fragmentDir -Force | Out-Null

# Download the icon next to the fragment, unless the user passed their own -Icon.
# The file name includes a hash of the image, so a different icon gets a
# different path. Windows Terminal caches icons by path, so reusing one name
# can leave the old picture on screen.
if (-not $Icon -and $IconUrl) {
    $download = Join-Path $fragmentDir 'download.tmp'
    try {
        # Windows PowerShell 5.1 may not enable TLS 1.2 by default
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $IconUrl -OutFile $download -UseBasicParsing
        $hash = (Get-FileHash $download -Algorithm SHA256).Hash.Substring(0, 8).ToLowerInvariant()
        $ext = [IO.Path]::GetExtension(([uri]$IconUrl).AbsolutePath)
        if (-not $ext) { $ext = '.png' }
        $iconFile = Join-Path $fragmentDir "claude-code-$hash$ext"
        Move-Item $download $iconFile -Force
        $Icon = $iconFile
    } catch {
        if (Test-Path $download) { Remove-Item $download -Force }
        Write-Warning "Couldn't download the icon from $IconUrl ($($_.Exception.Message)). Using an emoji instead."
    }
}
if (-not $Icon) { $Icon = [char]::ConvertFromUtf32(0x2733) }  # fallback: eight-spoked asterisk emoji

# --- Write the fragment ---------------------------------------------------
$wtProfile = [ordered]@{
    guid              = $profileGuid
    name              = $Name
    commandline       = $commandline
    startingDirectory = $StartingDirectory
    icon              = $Icon
    hidden            = $false
}
$fragment = @{ profiles = @($wtProfile) }

$json = $fragment | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($fragmentFile, $json, $utf8NoBom)

Write-Host "Added the '$Name' profile." -ForegroundColor Green

# --- Claude Code settings -------------------------------------------------
if (-not $SkipClaudeSettings) {
    $settings = & $readClaudeSettings
    if ($settings) {
        if (-not $settings.PSObject.Properties['env']) {
            $settings | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{})
        }
        $settings.env | Add-Member -NotePropertyName $envVarName -NotePropertyValue '1' -Force
        & $writeClaudeSettings $settings
        Write-Host "Set $envVarName=1 in $claudeSettingsFile"
    }
}

& $warnAboutIconOverrides

Write-Host "Fragment: $fragmentFile"
Write-Host "Close every Windows Terminal window, then reopen it and pick '$Name' from the new-tab dropdown."
