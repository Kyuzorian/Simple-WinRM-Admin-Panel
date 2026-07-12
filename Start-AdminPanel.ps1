Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Add-Type -AssemblyName System.Windows.Forms
try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
} catch {
    # Already set by a prior run in this session/thread; safe to ignore.
}
Import-Module (Join-Path $PSScriptRoot 'Gui.psm1') -Force
try {
    Show-AdminPanel
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "The admin panel failed to start:`n$($_.Exception.Message)",
        'Startup Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}