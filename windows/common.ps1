# Shared helpers for the Engineer Windows scripts (Windows PowerShell 5.1 compatible).

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'   # make wsl.exe print UTF-8 instead of UTF-16

$EngineerHome = Join-Path $env:LOCALAPPDATA 'Engineer'
$DistroFile = Join-Path $EngineerHome 'distro.txt'
$DefaultDistro = 'Ubuntu-24.04'
$UsagePort = 18080

function Say([string]$Text, [string]$Color = 'White') {
    Write-Host $Text -ForegroundColor $Color
}

function Fail([string]$Text) {
    Say ''
    Say $Text 'Red'
    Pause-Window
    exit 1
}

function Pause-Window {
    Say ''
    Read-Host 'Press Enter to close this window' | Out-Null
}

function Test-WslReady {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { return $false }
    & wsl.exe --version *> $null
    return $LASTEXITCODE -eq 0
}

function Get-Distros {
    $names = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($names | ForEach-Object { $_.Trim([char]0, ' ') } | Where-Object { $_ })
}

# Runs wsl.exe attached to this console window (so prompts and full-screen programs work)
# and returns its exit code. Distro names have no spaces, so they are not quoted
# (wsl.exe would keep the quotes as part of the name).
function Invoke-Wsl([string]$Arguments) {
    $process = Start-Process -FilePath 'wsl.exe' -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
    return $process.ExitCode
}

function Invoke-Linux([string]$Distro, [string]$Command) {
    return Invoke-Wsl "-d $Distro --cd ~ --exec bash -lc `"$Command`""
}

function Get-LinuxOutput([string]$Distro, [string]$Command) {
    $out = & wsl.exe -d $Distro --exec bash -c $Command 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return (($out | Out-String).Trim())
}

function Get-SavedDistro {
    if (Test-Path $DistroFile) {
        $name = (Get-Content $DistroFile -Raw).Trim()
        if ($name -and ((Get-Distros) -contains $name)) { return $name }
    }
    return $null
}

function Require-Installed {
    $distro = Get-SavedDistro
    if (-not $distro) { Fail 'Engineer is not installed yet. Run "Install Engineer" first.' }
    return $distro
}

function Start-KeepAwake([string]$Distro) {
    # WSL stops Ubuntu (and the dashboards) when no Windows program is using it,
    # so a hidden background process keeps it running until you sign out.
    $running = Get-CimInstance Win32_Process -Filter "Name = 'wsl.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*engineer-keep-awake*' }
    if ($running) { return }
    Start-Process -WindowStyle Hidden -FilePath 'wsl.exe' `
        -ArgumentList "-d $Distro --exec bash -c `"exec -a engineer-keep-awake sleep infinity`""
}
