# Installs Engineer for a Windows user: WSL, Ubuntu, Engineer itself, and Start menu shortcuts.
# Started by "Install Engineer.cmd". Safe to run again; it picks up where it left off.

. (Join-Path $PSScriptRoot 'common.ps1')

$Here = $PSScriptRoot
$Ref = 'main'
$RefFile = Join-Path (Split-Path $Here -Parent) 'engineer-ref.txt'
if (Test-Path $RefFile) { $Ref = (Get-Content $RefFile -Raw).Trim() }

function Copy-Scripts {
    New-Item -ItemType Directory -Force -Path $EngineerHome | Out-Null
    foreach ($name in 'common.ps1', 'Engineer.ps1', 'bootstrap.sh') {
        Copy-Item -Force (Join-Path $Here $name) (Join-Path $EngineerHome $name)
    }
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
    if ($parts[2] -notmatch 'microsoft-standard') { return $false }   # WSL 1 has no systemd
    try { return [version]$parts[1] -ge [version]'24.04' } catch { return $false }
}

function Ensure-User([string]$Distro) {
    $user = Get-LinuxOutput $Distro 'whoami'
    if ($user -and $user -ne 'root') { return }
    Say ''
    Say 'Ubuntu needs a user name and password of its own (they do not have to match Windows).' 'Cyan'
    do { $name = (Read-Host 'Choose a user name (lowercase letters, e.g. jsmith)').Trim() }
    until ($name -match '^[a-z][a-z0-9_-]{0,31}$')
    if ((Invoke-Wsl "-d `"$Distro`" -u root --exec adduser --gecos , $name") -ne 0) {
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

function Install-Engineer([string]$Distro) {
    Say ''
    Say 'Step 3: installing Engineer inside Ubuntu. The first time takes about 20 minutes.' 'Cyan'
    Say 'It explains each step and asks before changing anything. Ubuntu may ask for your Ubuntu password.'
    $script = Get-LinuxOutput $Distro ("wslpath -a '" + (Join-Path $EngineerHome 'bootstrap.sh') + "'")
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $code = Invoke-Linux $Distro "bash <(sed 's/\r$//' '$script') '$Ref'"
        if ($code -eq 0) { return }
        if ($code -ne 3) { Fail 'Engineer did not finish installing. Read the message above, then run "Install Engineer" again.' }
        Say 'Restarting Ubuntu to finish setup, then continuing...' 'Yellow'
        & wsl.exe --terminate $Distro | Out-Null
    }
    Fail 'Ubuntu still needs a restart. Restart your computer, then run "Install Engineer" again.'
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
    $menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Engineer'
    $desktop = [Environment]::GetFolderPath('Desktop')
    New-Item -ItemType Directory -Force -Path $menu | Out-Null
    Get-ChildItem $menu -Filter '*.lnk' | Remove-Item
    $copilot = Get-LinuxOutput $Distro 'test -x ~/.local/engineer/npm/bin/copilot && echo yes'
    $items = @(
        @('Pi (AI assistant)', 'pi', 12, $true),
        @('Update USAi key', 'key', 47, $true),
        @('AI usage dashboard', 'usage', 13, $true),
        @('Check Engineer', 'check', 23, $false),
        @('Update Engineer', 'update', 238, $false),
        @('Remove Engineer', 'remove', 31, $false)
    )
    if ($copilot -eq 'yes') { $items += , @('Copilot (AI assistant)', 'copilot', 12, $false) }
    foreach ($item in $items) {
        New-Shortcut $menu $item[0] $item[1] $item[2]
        if ($item[3]) { New-Shortcut $desktop $item[0] $item[1] $item[2] }
    }
    Say "Shortcuts added to the Start menu (Engineer folder) and the desktop." 'Green'
}

Say 'Engineer installer' 'Green'
Say 'You can run this again at any time; it continues where it left off.'
Say ''
Copy-Scripts
Ensure-Wsl
$distro = Ensure-Ubuntu
Install-Engineer $distro
Add-Shortcuts $distro
Say ''
Say 'Engineer is ready. Open "Pi (AI assistant)" from the Start menu or desktop to begin.' 'Green'
Pause-Window
