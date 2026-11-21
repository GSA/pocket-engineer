# Engineer shortcuts: each Start menu / desktop shortcut runs this script with one action.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('pi', 'copilot', 'key', 'usage', 'check', 'update', 'remove')]
    [string]$Action
)

. (Join-Path $PSScriptRoot 'common.ps1')

$distro = Require-Installed
$engineer = '~/engineer/engineer'

switch ($Action) {
    'pi' {
        $Host.UI.RawUI.WindowTitle = 'Pi (AI assistant)'
        Invoke-Linux $distro "$engineer pi" | Out-Null
    }
    'copilot' {
        $Host.UI.RawUI.WindowTitle = 'Copilot (AI assistant)'
        Invoke-Linux $distro "$engineer copilot" | Out-Null
    }
    'key' {
        $Host.UI.RawUI.WindowTitle = 'Update USAi key'
        Say 'Get your key from the USAi website, copy it, then paste it below.' 'Cyan'
        Say 'Tip: right-click pastes in this window. The key stays hidden while you paste.'
        Say ''
        if ((Invoke-Linux $distro "$engineer key") -eq 0) { Say 'Done.' 'Green' }
        Pause-Window
    }
    'usage' {
        Say 'Starting the AI usage dashboard...' 'Cyan'
        Start-KeepAwake $distro
        if ((Invoke-Linux $distro "$engineer start >/dev/null") -ne 0) {
            Fail 'The dashboard did not start. Open "Check Engineer" to see what is wrong.'
        }
        Start-Process "http://127.0.0.1:$UsagePort/"
    }
    'check' {
        $Host.UI.RawUI.WindowTitle = 'Check Engineer'
        Invoke-Linux $distro "$engineer doctor" | Out-Null
        Pause-Window
    }
    'update' {
        $Host.UI.RawUI.WindowTitle = 'Update Engineer'
        Invoke-Linux $distro "$engineer update" | Out-Null
        Pause-Window
    }
    'remove' {
        $Host.UI.RawUI.WindowTitle = 'Remove Engineer'
        Say 'This removes Engineer from Ubuntu. Your tasks, reviews and settings are kept unless you choose otherwise.'
        if ((Read-Host 'Type REMOVE to continue') -ne 'REMOVE') { exit 0 }
        if ((Invoke-Linux $distro "$engineer uninstall") -eq 0) {
            $menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Engineer'
            $desktop = [Environment]::GetFolderPath('Desktop')
            Remove-Item -Recurse -Force $menu -ErrorAction SilentlyContinue
            foreach ($name in 'Pi (AI assistant)', 'Update USAi key', 'AI usage dashboard') {
                Remove-Item -Force (Join-Path $desktop "$name.lnk") -ErrorAction SilentlyContinue
            }
            Say 'Engineer was removed. Ubuntu itself is still installed.' 'Green'
        }
        Pause-Window
    }
}
