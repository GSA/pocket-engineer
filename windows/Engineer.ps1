# Engineer desktop shortcuts: each one runs this script with one action.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('pi', 'copilot', 'key', 'usage')]
    [string]$Action
)

. (Join-Path $PSScriptRoot 'common.ps1')

$distro = Require-Installed

function Open-Assistant([string]$Title, [string]$Name) {
    $Host.UI.RawUI.WindowTitle = $Title
    Say 'Updating the USAi model list...' 'Cyan'
    if ((Invoke-Linux $distro "$Launcher $Name") -ne 0) { Pause-Window }
}

function Test-Dashboard {
    try {
        $null = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$DashboardPort/api/ping"
        return $true
    } catch { return $false }
}

switch ($Action) {
    'pi' { Open-Assistant 'Pi (AI assistant)' 'pi' }
    'copilot' { Open-Assistant 'Copilot (AI assistant)' 'copilot' }
    'key' {
        $Host.UI.RawUI.WindowTitle = 'Update USAi key'
        Say 'Get your key from the USAi website, copy it, then paste it below.' 'Cyan'
        Say 'Tip: right-click pastes in this window. The key stays hidden while you paste.'
        Say ''
        Invoke-Linux $distro "$Launcher key" | Out-Null
        Pause-Window
    }
    'usage' {
        if (-not (Test-Dashboard)) {
            Say 'Starting the AI usage dashboard...' 'Cyan'
            # The hidden process keeps Ubuntu (and the dashboard) running until you sign out.
            Start-Process -WindowStyle Hidden -FilePath 'wsl.exe' `
                -ArgumentList "-d $distro --cd ~ --exec bash -lc `"$Launcher dashboard`""
            $deadline = (Get-Date).AddSeconds(60)
            while (-not (Test-Dashboard)) {
                if ((Get-Date) -gt $deadline) { Fail 'The dashboard did not start. Run "Install Engineer" again.' }
                Start-Sleep -Seconds 1
            }
        }
        Start-Process "http://127.0.0.1:$DashboardPort/"
    }
}
