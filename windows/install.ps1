# Installs Engineer for a Windows user: WSL, Ubuntu, Pi and/or Copilot on USAi, and desktop shortcuts.
# Started by "Install Engineer.cmd". Safe to run again; it picks up where it left off.

. (Join-Path $PSScriptRoot 'common.ps1')

$Here = $PSScriptRoot
$LinuxSource = Join-Path (Split-Path $Here -Parent) 'linux'

function Copy-Scripts {
    New-Item -ItemType Directory -Force -Path $EngineerHome | Out-Null
    foreach ($name in 'common.ps1', 'Engineer.ps1') {
        Copy-Item -Force (Join-Path $Here $name) (Join-Path $EngineerHome $name)
    }
    Remove-Item -Force (Join-Path $EngineerHome 'bootstrap.sh') -ErrorAction SilentlyContinue
    Get-ChildItem $EngineerHome -File | Unblock-File
}

function Ensure-Wsl {
    if (Test-WslReady) { return }
    Say 'Step 1: turning on WSL (the part of Windows that runs Ubuntu).' 'Cyan'
    Say 'Windows will ask for permission. Choose "Yes".'
    try {
        Start-Process -FilePath 'wsl.exe' -ArgumentList '--install', '--no-distribution' -Verb RunAs -Wait
    } catch {
        Fail 'WSL was not turned on (permission was declined). Run "Install Engineer" again and choose "Yes".'
    }
    if (-not (Test-WslReady)) {
        Say ''
        Say 'WSL is installed. RESTART YOUR COMPUTER, then double-click "Install Engineer" again.' 'Yellow'
        Pause-Window
        exit 0
    }
}

function Test-GoodUbuntu([string]$Distro) {
    $info = Get-LinuxOutput $Distro '. /etc/os-release; echo $ID $VERSION_ID $(uname -r)'
    $parts = $info -split ' '
    if ($parts.Count -lt 3 -or $parts[0] -ne 'ubuntu') { return $false }
    if ($parts[2] -notmatch 'microsoft-standard') { return $false }   # WSL 2 only
    try { return [version]$parts[1] -ge [version]'24.04' } catch { return $false }
}

function Ensure-User([string]$Distro) {
    $user = Get-LinuxOutput $Distro 'whoami'
    if ($user -and $user -ne 'root') { return }
    Say ''
    Say 'Ubuntu needs a user name and password of its own (they do not have to match Windows).' 'Cyan'
    do { $name = (Read-Host 'Choose a user name (lowercase letters, e.g. jsmith)').Trim() }
    until ($name -match '^[a-z][a-z0-9_-]{0,31}$')
    if ((Invoke-Wsl "-d $Distro -u root --exec adduser --gecos , $name") -ne 0) {
        Fail 'Could not create the Ubuntu user. Run "Install Engineer" again.'
    }
    & wsl.exe -d $Distro -u root --exec usermod -aG sudo $name | Out-Null
    & wsl.exe -d $Distro -u root --exec sh -c "grep -q '^\[user\]' /etc/wsl.conf 2>/dev/null || printf '\n[user]\ndefault=$name\n' >> /etc/wsl.conf" | Out-Null
    & wsl.exe --terminate $Distro | Out-Null
}

function Ensure-Ubuntu {
    $distro = Get-SavedDistro
    if (-not $distro) {
        $distro = Get-Distros | Where-Object { $_ -like 'Ubuntu*' } |
            Where-Object { Test-GoodUbuntu $_ } | Select-Object -First 1
    }
    if (-not $distro) {
        $distro = $DefaultDistro
        Say "Step 2: installing $distro. This downloads about 1 GB." 'Cyan'
        if ((Invoke-Wsl "--install -d $distro --no-launch") -ne 0) { Fail "Could not install $distro. Check your network connection and try again." }
        Say 'If Ubuntu asks you to create a user name and password, do that now.' 'Yellow'
        Invoke-Wsl "-d $distro --exec true" | Out-Null
    }
    if (-not (Test-GoodUbuntu $distro)) { Fail "$distro is not Ubuntu 24.04 or newer on WSL 2." }
    Ensure-User $distro
    Set-Content -Path $DistroFile -Value $distro -Encoding ASCII
    return $distro
}

function Read-Choices {
    Say ''
    Say 'Which AI assistant do you want? Both use GSA''s USAi models.' 'Cyan'
    Say '  1. Pi'
    Say '  2. GitHub Copilot CLI'
    Say '  3. Both'
    do { $answer = (Read-Host 'Type 1, 2 or 3 (press Enter for 1)').Trim() }
    until ($answer -in '', '1', '2', '3')
    $choices = @(switch ($answer) { '2' { @('copilot') } '3' { @('pi', 'copilot') } default { @('pi') } })
    Say ''
    Say 'Optional: AI usage dashboard (AgentsView)' 'Cyan'
    Say 'A web page, opened from a desktop shortcut, that lists your past Pi and Copilot'
    Say 'sessions and shows how many tokens you have used. It runs only on this PC and'
    Say 'reads the session history Pi and Copilot already keep; nothing is sent anywhere.'
    Say 'You do not need it to use Pi or Copilot.'
    if ((Read-Host 'Install the AI usage dashboard? [y/N]').Trim() -match '^(y|yes)$') { $choices += 'agentsview' }
    return $choices
}

function Install-Tools([string]$Distro, [string[]]$Choices) {
    Say ''
    Say 'Step 3: installing your choices inside Ubuntu. This takes a few minutes.' 'Cyan'
    Say 'Ubuntu may ask for your Ubuntu password.'
    $source = Get-LinuxOutput $Distro "wslpath -a '$LinuxSource'"
    if (-not $source) { Fail 'Could not find the installer files. Unzip the whole download, then run "Install Engineer" again.' }
    $command = "SIMPLE_ENGINEER_SOURCE='$source' bash <(sed 's/\r$//' '$source/install.sh') $($Choices -join ' ')"
    if ((Invoke-Linux $Distro $command) -ne 0) {
        Fail 'Engineer did not finish installing. Read the message above, then run "Install Engineer" again.'
    }
    Say ''
    Say 'Step 4: your USAi key.' 'Cyan'
    Say 'Copy your key from the USAi website. Right-click pastes in this window; the key stays hidden.'
    if ((Invoke-Linux $Distro "$Launcher ensure-key") -ne 0) {
        Say 'No key was saved. Double-click "Update USAi key" on your desktop to add it later.' 'Yellow'
    }
}

function New-Shortcut([string]$Folder, [string]$Name, [string]$Action, [int]$Icon) {
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $Folder "$Name.lnk"))
    $link.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $EngineerHome 'Engineer.ps1')`" -Action $Action"
    $link.WorkingDirectory = $EngineerHome
    $link.IconLocation = "$env:SystemRoot\System32\shell32.dll,$Icon"
    $link.Save()
}

function Add-Shortcuts([string]$Distro) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    # Earlier versions also added a Start menu folder; its shortcuts no longer work.
    Remove-Item -Recurse -Force (Join-Path ([Environment]::GetFolderPath('Programs')) 'Engineer') -ErrorAction SilentlyContinue
    $installed = (Get-LinuxOutput $Distro 'cd ~/.local/share/simple-engineer && for t in npm/bin/pi npm/bin/copilot bin/agentsview; do test -x $t && basename $t; done; true') -split "`n" |
        ForEach-Object { $_.Trim() }
    $items = @(
        @('Pi (AI assistant)', 'pi', 12, 'pi'),
        @('Copilot (AI assistant)', 'copilot', 12, 'copilot'),
        @('Update USAi key', 'key', 47, $null),
        @('AI usage dashboard', 'usage', 13, 'agentsview')
    )
    foreach ($item in $items) {
        if ($null -eq $item[3] -or $installed -contains $item[3]) {
            New-Shortcut $desktop $item[0] $item[1] $item[2]
        } else {
            Remove-Item -Force (Join-Path $desktop "$($item[0]).lnk") -ErrorAction SilentlyContinue
        }
    }
    Say 'Shortcuts added to your desktop.' 'Green'
}

Say 'Engineer installer' 'Green'
Say 'You can run this again at any time; it continues where it left off.'
Say ''
Copy-Scripts
Ensure-Wsl
$distro = Ensure-Ubuntu
$choices = Read-Choices
Install-Tools $distro $choices
Add-Shortcuts $distro
Say ''
Say 'Engineer is ready. Double-click your AI assistant''s shortcut on the desktop to begin.' 'Green'
Pause-Window
