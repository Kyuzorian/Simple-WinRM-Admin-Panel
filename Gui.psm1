using namespace System.Windows.Forms
using namespace System.Drawing

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Import-Module (Join-Path $PSScriptRoot 'Core.psm1') -Force

#region Theme
$Theme = @{
    Background          = [Color]::FromArgb(24,24,27)
    AlternateBackground = [Color]::FromArgb(32,32,36)
    SidebarBackground   = [Color]::FromArgb(20,20,23)
    BorderColor         = [Color]::FromArgb(50,50,55)
    TextColor           = [Color]::FromArgb(230,230,230)
    SecondaryTextColor  = [Color]::FromArgb(150,150,155)
    AccentColor         = [Color]::FromArgb(0,122,204)
    SuccessColor        = [Color]::FromArgb(80,200,120)
    ErrorColor          = [Color]::FromArgb(220,80,80)
    WarningColor        = [Color]::FromArgb(220,180,60)
    DisabledColor       = [Color]::FromArgb(130,130,138)
    RegularFont         = [Font]::new('Segoe UI',9)
    BoldFont            = [Font]::new('Segoe UI',10,[FontStyle]::Bold)
    HeaderFont          = [Font]::new('Segoe UI',8,[FontStyle]::Bold)
}
#endregion

#region UIFactory
function New-AdminButton {
    param([string]$ButtonText, [int]$XPosition, [int]$YPosition, [int]$Width, [int]$Height, [Color]$BackgroundColor = $Theme.AccentColor, [Color]$ForegroundColor = [Color]::White)
    $Button = New-Object System.Windows.Forms.Button -Property @{
        Text=$ButtonText; Location=[Point]::new($XPosition,$YPosition); Size=[Size]::new($Width,$Height)
        FlatStyle='Flat'; BackColor=$BackgroundColor; ForeColor=$ForegroundColor; Font=$Theme.RegularFont; Cursor='Hand'
    }
    $Button.FlatAppearance.BorderSize = 0
    $Button.TabStop = $false
    return $Button
}

function New-AdminLabel {
    param([string]$LabelText, [int]$XPosition, [int]$YPosition, [int]$Width = 200, [int]$Height = 20, [Color]$ForegroundColor = $Theme.TextColor, [Font]$Font = $Theme.RegularFont)
    New-Object System.Windows.Forms.Label -Property @{
        Text=$LabelText; Location=[Point]::new($XPosition,$YPosition); Size=[Size]::new($Width,$Height)
        ForeColor=$ForegroundColor; Font=$Font; BackColor=[Color]::Transparent
    }
}

function New-AdminTextBox {
    param([int]$XPosition, [int]$YPosition, [int]$Width, [int]$Height = 22, [switch]$IsPassword, [int]$TabIndex)
    $TextBox = New-Object System.Windows.Forms.TextBox -Property @{
        Location=[Point]::new($XPosition,$YPosition); Size=[Size]::new($Width,$Height)
        BackColor=$Theme.AlternateBackground; ForeColor=$Theme.TextColor; BorderStyle='FixedSingle'
    }
    if ($IsPassword) { $TextBox.UseSystemPasswordChar = $true }
    if ($null -ne $TabIndex) { $TextBox.TabIndex = $TabIndex }
    return $TextBox
}

function New-AdminDataGrid {
    param([int]$XPosition, [int]$YPosition, [int]$Width, [int]$Height, [string[]]$ColumnNames)
    $DataGrid = New-Object System.Windows.Forms.DataGridView -Property @{
        Location=[Point]::new($XPosition,$YPosition); Size=[Size]::new($Width,$Height)
        BackgroundColor=$Theme.Background; GridColor=$Theme.BorderColor; BorderStyle='None'
        RowHeadersVisible=$false; AllowUserToAddRows=$false; AllowUserToDeleteRows=$false; AllowUserToResizeRows=$false
        ReadOnly=$true; SelectionMode='FullRowSelect'; MultiSelect=$false; AutoSizeColumnsMode='Fill'
        EnableHeadersVisualStyles=$false; ColumnHeadersBorderStyle='None'; CellBorderStyle='None'
    }
    $DataGrid.ColumnHeadersDefaultCellStyle.BackColor = $Theme.SidebarBackground
    $DataGrid.ColumnHeadersDefaultCellStyle.ForeColor = $Theme.TextColor
    $DataGrid.ColumnHeadersDefaultCellStyle.Font = $Theme.BoldFont
    $DataGrid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $Theme.SidebarBackground
    $DataGrid.DefaultCellStyle.BackColor = $Theme.AlternateBackground
    $DataGrid.DefaultCellStyle.ForeColor = $Theme.TextColor
    $DataGrid.DefaultCellStyle.SelectionBackColor = $Theme.AccentColor
    $DataGrid.DefaultCellStyle.SelectionForeColor = [Color]::White
    $DataGrid.AlternatingRowsDefaultCellStyle.BackColor = $Theme.Background
    $DataGrid.RowsDefaultCellStyle.BackColor = $Theme.AlternateBackground
    $DataGrid.RowTemplate.Height = 26
    foreach ($ColumnName in $ColumnNames) { $DataGrid.Columns.Add($ColumnName,$ColumnName) | Out-Null }
    return $DataGrid
}

function New-ContentPanel {
    New-Object System.Windows.Forms.Panel -Property @{
        Size=[Size]::new(480,440); Location=[Point]::new(0,0); BackColor=$Theme.Background; Visible=$false
    }
}

function New-Separator {
    param([int]$XPosition, [int]$YPosition, [int]$Width)
    New-Object System.Windows.Forms.Panel -Property @{
        Location=[Point]::new($XPosition,$YPosition); Size=[Size]::new($Width,1); BackColor=$Theme.BorderColor
    }
}

function Set-ButtonEnabledState {
    param([System.Windows.Forms.Button]$Button, [bool]$IsEnabled)
    if (-not $Button.Tag) { $Button.Tag = $Button.ForeColor }
    $Button.ForeColor = if ($IsEnabled) { $Button.Tag } else { $Theme.DisabledColor }
    $Button.Cursor = if ($IsEnabled) { 'Hand' } else { 'Default' }
    $Button.Enabled = $IsEnabled
}

function Register-SearchFilter {
    param([System.Windows.Forms.TextBox]$TextBox, [scriptblock]$GetSource, [scriptblock]$SetRows, [string[]]$MatchFields)
    $TextBox.Add_TextChanged({
        $SearchTerm = $TextBox.Text.Trim()
        $CurrentServer = Get-ActiveServer
        if (-not $CurrentServer) { return }
        $Source = & $GetSource $CurrentServer
        if ($SearchTerm) { $Source = $Source | Where-Object { $Item = $_; @($MatchFields | Where-Object { $Item.$_ -like "*$SearchTerm*" }).Count -gt 0 } }
        & $SetRows $Source
    }.GetNewClosure())
}
#endregion

function Show-AdminPanel {

#region MainWindow
$Form = New-Object System.Windows.Forms.Form -Property @{
    Text='Remote Admin Control Panel'; ClientSize=[Size]::new(670,640)
    StartPosition='CenterScreen'; BackColor=$Theme.Background; FormBorderStyle='FixedSingle'; MaximizeBox=$false
}

$TopBarPanel = New-Object System.Windows.Forms.Panel -Property @{
    Size=[Size]::new(670,44); Location=[Point]::new(0,0); BackColor=$Theme.Background
}
$Form.Controls.Add($TopBarPanel)

$LabelTitle = New-AdminLabel -LabelText 'ADMIN PANEL' -XPosition 16 -YPosition 13 -Width 160 -Height 22 -ForegroundColor $Theme.TextColor -Font $Theme.BoldFont
$LabelUser  = New-AdminLabel -LabelText 'User:' -XPosition 190 -YPosition 15 -Width 34 -Height 18 -ForegroundColor $Theme.SecondaryTextColor
$TextBoxUser = New-AdminTextBox -XPosition 224 -YPosition 12 -Width 120 -Height 22 -TabIndex 0
$LabelPass  = New-AdminLabel -LabelText 'Pass:' -XPosition 358 -YPosition 15 -Width 34 -Height 18 -ForegroundColor $Theme.SecondaryTextColor
$TextBoxPass = New-AdminTextBox -XPosition 392 -YPosition 12 -Width 120 -Height 22 -IsPassword -TabIndex 1
$ButtonLogin = New-AdminButton -ButtonText 'Sign In' -XPosition 524 -YPosition 10 -Width 90 -Height 26 -BackgroundColor $Theme.AccentColor
$ButtonLogin.TabIndex = 2
$LabelSignedInAs = New-AdminLabel -LabelText '' -XPosition 190 -YPosition 15 -Width 300 -Height 18 -ForegroundColor $Theme.SecondaryTextColor
$LabelSignedInAs.Visible = $false
$TopBarSeparator = New-Separator -XPosition 0 -YPosition 43 -Width 670
$TopBarPanel.Controls.AddRange(@($LabelTitle,$LabelUser,$TextBoxUser,$LabelPass,$TextBoxPass,$ButtonLogin,$LabelSignedInAs,$TopBarSeparator))

$SidebarPanel = New-Object System.Windows.Forms.Panel -Property @{
    Size=[Size]::new(190,596); Location=[Point]::new(0,44); BackColor=$Theme.Background
}
$Form.Controls.Add($SidebarPanel)
$SidebarSeparator = New-Separator -XPosition 189 -YPosition 0 -Width 1
$SidebarSeparator.Height = 596
$SidebarPanel.Controls.Add($SidebarSeparator)

$LabelStatusHeader = New-AdminLabel -LabelText 'STATUS' -XPosition 16 -YPosition 14 -Width 158 -Height 14 -ForegroundColor $Theme.SecondaryTextColor -Font $Theme.HeaderFont
$LabelRebootKey    = New-AdminLabel -LabelText 'Reboot Needed:' -XPosition 16 -YPosition 32 -Width 158 -Height 16 -ForegroundColor $Theme.SecondaryTextColor
$LabelRebootValue  = New-AdminLabel -LabelText '' -XPosition 16 -YPosition 50 -Width 158 -Height 16 -ForegroundColor $Theme.SecondaryTextColor
$SeparatorStatus   = New-Separator -XPosition 16 -YPosition 72 -Width 158
$SidebarPanel.Controls.AddRange(@($LabelStatusHeader,$LabelRebootKey,$LabelRebootValue,$SeparatorStatus))

$LabelServersHeader = New-AdminLabel -LabelText 'SERVERS' -XPosition 16 -YPosition 84 -Width 158 -Height 14 -ForegroundColor $Theme.SecondaryTextColor -Font $Theme.HeaderFont
$SidebarPanel.Controls.Add($LabelServersHeader)

$ListServers = New-Object System.Windows.Forms.ListBox -Property @{
    Location=[Point]::new(16,102); Size=[Size]::new(158,100)
    BackColor=$Theme.AlternateBackground; ForeColor=$Theme.TextColor; BorderStyle='FixedSingle'; Font=$Theme.RegularFont
}
$SidebarPanel.Controls.Add($ListServers)

$ButtonAddServer  = New-AdminButton -ButtonText '+ Add Server' -XPosition 16 -YPosition 210 -Width 158 -Height 28 -BackgroundColor $Theme.AlternateBackground
$ButtonDisconnect = New-AdminButton -ButtonText 'Disconnect' -XPosition 16 -YPosition 242 -Width 158 -Height 28 -BackgroundColor $Theme.AlternateBackground
$ButtonSignOut    = New-AdminButton -ButtonText 'Sign Out' -XPosition 16 -YPosition 274 -Width 158 -Height 28 -BackgroundColor $Theme.AlternateBackground
$SeparatorActions = New-Separator -XPosition 16 -YPosition 306 -Width 158
$SidebarPanel.Controls.AddRange(@($ButtonAddServer,$ButtonDisconnect,$ButtonSignOut,$SeparatorActions))

$LabelViewsHeader = New-AdminLabel -LabelText 'LIVE VIEWS' -XPosition 16 -YPosition 318 -Width 158 -Height 14 -ForegroundColor $Theme.SecondaryTextColor -Font $Theme.HeaderFont
$SidebarPanel.Controls.Add($LabelViewsHeader)

$ButtonNavigationServices  = New-AdminButton -ButtonText 'Core Services' -XPosition 16 -YPosition 336 -Width 158 -Height 30 -BackgroundColor $Theme.AlternateBackground
$ButtonNavigationProcesses = New-AdminButton -ButtonText 'System Processes' -XPosition 16 -YPosition 370 -Width 158 -Height 30 -BackgroundColor $Theme.AlternateBackground
$ButtonNavigationDisks     = New-AdminButton -ButtonText 'Disk Space' -XPosition 16 -YPosition 404 -Width 158 -Height 30 -BackgroundColor $Theme.AlternateBackground
$ButtonNavigationRestart   = New-AdminButton -ButtonText 'Power Actions' -XPosition 16 -YPosition 438 -Width 158 -Height 30 -BackgroundColor $Theme.AlternateBackground
$SidebarPanel.Controls.AddRange(@($ButtonNavigationServices,$ButtonNavigationProcesses,$ButtonNavigationDisks,$ButtonNavigationRestart))

$ContentPanel = New-Object System.Windows.Forms.Panel -Property @{
    Location=[Point]::new(190,44); Size=[Size]::new(480,450); BackColor=$Theme.Background
}
$Form.Controls.Add($ContentPanel)

$LabelLogHeader = New-AdminLabel -LabelText 'ACTIVITY LOG' -XPosition 200 -YPosition 500 -Width 200 -Height 14 -ForegroundColor $Theme.SecondaryTextColor -Font $Theme.HeaderFont
$Form.Controls.Add($LabelLogHeader)

$ActivityLogListBox = New-Object System.Windows.Forms.ListBox -Property @{
    Location=[Point]::new(200,518); Size=[Size]::new(460,104)
    BackColor=$Theme.SidebarBackground; ForeColor=$Theme.SecondaryTextColor; BorderStyle='FixedSingle'
    Font=[Font]::new('Consolas',8.5); DrawMode='OwnerDrawFixed'; ItemHeight=14
    HorizontalScrollbar=$false; ScrollAlwaysVisible=$true
}
$ActivityLogTooltip = New-Object System.Windows.Forms.ToolTip
$ActivityLogListBox.Add_MouseMove({
    param([object]$Sender, [System.EventArgs]$EventArgs)
    $ItemIndex = $ActivityLogListBox.IndexFromPoint($EventArgs.Location)
    if ($ItemIndex -ge 0 -and $ItemIndex -lt $ActivityLogListBox.Items.Count) {
        $ItemText = $ActivityLogListBox.Items[$ItemIndex].ToString()
        if ($ActivityLogTooltip.GetToolTip($ActivityLogListBox) -ne $ItemText) { $ActivityLogTooltip.SetToolTip($ActivityLogListBox,$ItemText) }
    } else {
        $ActivityLogTooltip.SetToolTip($ActivityLogListBox,'')
    }
})
$LogEntryBrushes = @{
    Default = [SolidBrush]::new($Theme.SecondaryTextColor)
    Fail    = [SolidBrush]::new([Color]::Magenta)
    Ok      = [SolidBrush]::new([Color]::Cyan)
}
$ActivityLogListBox.Add_DrawItem({
    param([object]$Sender, [System.EventArgs]$EventArgs)
    if ($EventArgs.Index -lt 0) { return }
    $LogEntryText = $ActivityLogListBox.Items[$EventArgs.Index]
    $EntryBrush = $LogEntryBrushes.Default
    if ($LogEntryText.Contains('[FAIL]'))   { $EntryBrush = $LogEntryBrushes.Fail }
    elseif ($LogEntryText.Contains('[OK]')) { $EntryBrush = $LogEntryBrushes.Ok }
    $EventArgs.DrawBackground()
    $MaxTextWidth = $EventArgs.Bounds.Width - 4
    $DisplayText = $LogEntryText
    if ($EventArgs.Graphics.MeasureString($DisplayText,$ActivityLogListBox.Font).Width -gt $MaxTextWidth) {
        $Low = 0; $High = $DisplayText.Length
        while ($Low -lt $High) {
            $Mid = [int](($Low + $High + 1) / 2)
            $Candidate = $DisplayText.Substring(0,$Mid) + '...'
            if ($EventArgs.Graphics.MeasureString($Candidate,$ActivityLogListBox.Font).Width -le $MaxTextWidth) { $Low = $Mid } else { $High = $Mid - 1 }
        }
        $DisplayText = $DisplayText.Substring(0,$Low) + '...'
    }
    $EventArgs.Graphics.DrawString($DisplayText, $ActivityLogListBox.Font, $EntryBrush, [PointF]::new($EventArgs.Bounds.X, $EventArgs.Bounds.Y))
})
$Form.Controls.Add($ActivityLogListBox)

function Add-Log {
    param([string]$Message,[string]$Level = 'Info')
    $Timestamp = Get-Date -Format 'HH:mm:ss'
    $LevelTag = switch ($Level) { 'Success' {'[OK]'} 'Fail' {'[FAIL]'} default {'[INFO]'} }
    $ActivityLogListBox.Items.Add("[$Timestamp] $LevelTag $Message") | Out-Null
    while ($ActivityLogListBox.Items.Count -gt 500) { $ActivityLogListBox.Items.RemoveAt(0) }
    $ActivityLogListBox.TopIndex = $ActivityLogListBox.Items.Count - 1
}

function Set-FailureStatus {
    param([System.Windows.Forms.Label]$Label, [string]$LogMessage, $ErrorRecord)
    if ($Label) { $Label.ForeColor = $Theme.ErrorColor; $Label.Text = "Failed: $($ErrorRecord.Exception.Message)" }
    Add-Log "$LogMessage`: $($ErrorRecord.Exception.Message)" 'Fail'
}
#endregion

#region LoginStatus
$LabelLoginStatus = New-AdminLabel -LabelText '' -XPosition 10 -YPosition 10 -Width 460 -Height 20 -ForegroundColor $Theme.ErrorColor
$ContentPanel.Controls.Add($LabelLoginStatus)
#endregion

#region PanelSwitch (add additional server - reuses stored credential)
$PanelSwitch = New-ContentPanel
$LabelSwitchTitle = New-AdminLabel -LabelText 'Add Server' -XPosition 20 -YPosition 15 -Width 300 -Height 25 -ForegroundColor $Theme.TextColor -Font $Theme.BoldFont
$LabelSwitchSubtitle = New-AdminLabel -LabelText 'Reuses current credentials.' -XPosition 20 -YPosition 48 -Width 400 -Height 20 -ForegroundColor $Theme.SecondaryTextColor
$LabelNewServer = New-AdminLabel -LabelText 'Server' -XPosition 20 -YPosition 80 -Width 200 -Height 18
$TextBoxNewServer = New-AdminTextBox -XPosition 20 -YPosition 98 -Width 200 -Height 24
$ButtonConnectNewServer = New-AdminButton -ButtonText 'Connect' -XPosition 20 -YPosition 140 -Width 150 -Height 30 -BackgroundColor $Theme.AccentColor
$LabelSwitchStatus = New-AdminLabel -LabelText '' -XPosition 20 -YPosition 180 -Width 400 -Height 40 -ForegroundColor $Theme.SecondaryTextColor

$PanelSwitch.Controls.AddRange(@($LabelSwitchTitle,$LabelSwitchSubtitle,$LabelNewServer,$TextBoxNewServer,$ButtonConnectNewServer,$LabelSwitchStatus))
$ContentPanel.Controls.Add($PanelSwitch)
#endregion

#region PanelServices
$PanelServices = New-ContentPanel
$LabelServicesTitle = New-AdminLabel -LabelText 'Services' -XPosition 20 -YPosition 15 -Width 200 -Height 25 -ForegroundColor $Theme.TextColor -Font $Theme.BoldFont
$TextBoxServiceSearch = New-AdminTextBox -XPosition 250 -YPosition 17 -Width 140 -Height 24
$ButtonRefreshServices = New-AdminButton -ButtonText 'Refresh' -XPosition 400 -YPosition 15 -Width 70 -Height 28 -BackgroundColor $Theme.AlternateBackground

$ServiceGrid = New-AdminDataGrid -XPosition 20 -YPosition 55 -Width 440 -Height 310 -ColumnNames @('Name','DisplayName','Status','StartMode')
$ServiceGrid.Columns[1].HeaderText = 'Display Name'
$ServiceGrid.Columns[3].HeaderText = 'Startup'

$ButtonStartService   = New-AdminButton -ButtonText 'Start' -XPosition 20 -YPosition 375 -Width 80 -Height 30 -BackgroundColor $Theme.SuccessColor
$ButtonStopService    = New-AdminButton -ButtonText 'Stop' -XPosition 110 -YPosition 375 -Width 80 -Height 30 -BackgroundColor $Theme.ErrorColor
$ButtonRestartService = New-AdminButton -ButtonText 'Restart' -XPosition 200 -YPosition 375 -Width 80 -Height 30 -BackgroundColor $Theme.WarningColor -ForegroundColor ([Color]::Black)
$LabelServiceStatus = New-AdminLabel -LabelText '' -XPosition 20 -YPosition 412 -Width 440 -Height 20 -ForegroundColor $Theme.SecondaryTextColor

$PanelServices.Controls.AddRange(@($LabelServicesTitle,$TextBoxServiceSearch,$ButtonRefreshServices,$ServiceGrid,$ButtonStartService,$ButtonStopService,$ButtonRestartService,$LabelServiceStatus))
$ContentPanel.Controls.Add($PanelServices)
#endregion

#region PanelProcesses
$PanelProcesses = New-ContentPanel
$LabelProcessesTitle = New-AdminLabel -LabelText 'Processes' -XPosition 20 -YPosition 15 -Width 200 -Height 25 -ForegroundColor $Theme.TextColor -Font $Theme.BoldFont
$TextBoxProcessSearch = New-AdminTextBox -XPosition 250 -YPosition 17 -Width 140 -Height 24
$ButtonRefreshProcesses = New-AdminButton -ButtonText 'Refresh' -XPosition 400 -YPosition 15 -Width 70 -Height 28 -BackgroundColor $Theme.AlternateBackground
$ProcessGrid = New-AdminDataGrid -XPosition 20 -YPosition 55 -Width 440 -Height 310 -ColumnNames @('Id','Name','CPU','MemoryMB')
$ProcessGrid.Columns[3].HeaderText = 'Memory (MB)'
$ButtonEndProcess = New-AdminButton -ButtonText 'End Process' -XPosition 20 -YPosition 375 -Width 120 -Height 30 -BackgroundColor $Theme.ErrorColor
$LabelProcessStatus = New-AdminLabel -LabelText '' -XPosition 20 -YPosition 412 -Width 440 -Height 20 -ForegroundColor $Theme.SecondaryTextColor
$PanelProcesses.Controls.AddRange(@($LabelProcessesTitle,$TextBoxProcessSearch,$ButtonRefreshProcesses,$ProcessGrid,$ButtonEndProcess,$LabelProcessStatus))
$ContentPanel.Controls.Add($PanelProcesses)

function Set-ProcessGridRows {
    param([object[]]$ProcessRows)
    $ProcessGrid.SuspendLayout()
    $ProcessGrid.Rows.Clear()
    foreach ($Process in $ProcessRows) { $ProcessGrid.Rows.Add($Process.Id,$Process.Name,$Process.CPU,$Process.MemoryMB) | Out-Null }
    $ProcessGrid.ResumeLayout()
}

function Update-ProcessList {
    if (-not (Test-ActiveSession)) { return }
    $CurrentServer = Get-ActiveServer
    $LabelProcessStatus.ForeColor = $Theme.SecondaryTextColor
    $LabelProcessStatus.Text = 'Loading...'
    $Form.Refresh()
    try {
        $Processes = Get-RemoteProcesses -ServerContext $CurrentServer
        $CurrentServer.Processes = $Processes
        Set-ProcessGridRows $Processes
        $LabelProcessStatus.Text = "Loaded $($Processes.Count) processes."
        Add-Log "Loaded $($Processes.Count) processes from $($CurrentServer.Name)" 'Success'
    } catch {
        Set-FailureStatus -Label $LabelProcessStatus -LogMessage 'Failed to load processes' -ErrorRecord $_
    }
}

Register-SearchFilter -TextBox $TextBoxProcessSearch -GetSource { param($s) $s.Processes } -SetRows { param($r) Set-ProcessGridRows $r } -MatchFields @('Name')

$ButtonRefreshProcesses.Add_Click({ Invoke-Refresh -Button $ButtonRefreshProcesses -CooldownKey 'Processes' -Action { Update-ProcessList } })
$ButtonEndProcess.Add_Click({
    if (-not (Test-RefreshCooldown -Key 'EndProcess')) { return }
    if ($ProcessGrid.SelectedRows.Count -eq 0) { $LabelProcessStatus.Text = 'Select a process.'; return }
    $ProcessId = [int]$ProcessGrid.SelectedRows[0].Cells[0].Value
    $ProcessName = [string]$ProcessGrid.SelectedRows[0].Cells[1].Value
    $ConfirmResult = [MessageBox]::Show(
        "End process '$ProcessName' (PID $ProcessId)?", 'Confirm End Process',
        [MessageBoxButtons]::YesNo, [MessageBoxIcon]::Warning)
    if ($ConfirmResult -ne [DialogResult]::Yes) { return }
    try {
        Stop-RemoteProcess -ServerContext (Get-ActiveServer) -ProcessId $ProcessId
        $LabelProcessStatus.ForeColor = $Theme.SuccessColor
        $LabelProcessStatus.Text = "Ended: $ProcessName ($ProcessId)"
        Add-Log "Ended process $ProcessName ($ProcessId)" 'Success'
    } catch {
        Set-FailureStatus -Label $LabelProcessStatus -LogMessage "Failed to end $ProcessName" -ErrorRecord $_
    }
    Update-ProcessList
})
#endregion

#region PanelDisks
$PanelDisks = New-ContentPanel
$LabelDisksTitle = New-AdminLabel -LabelText 'Disks' -XPosition 20 -YPosition 15 -Width 200 -Height 25 -ForegroundColor $Theme.TextColor -Font $Theme.BoldFont
$ButtonRefreshDisks = New-AdminButton -ButtonText 'Refresh' -XPosition 400 -YPosition 15 -Width 70 -Height 28 -BackgroundColor $Theme.AlternateBackground

$DiskGrid = New-AdminDataGrid -XPosition 20 -YPosition 55 -Width 440 -Height 360 -ColumnNames @('Drive','Used','Free','Total','UsedPct')
$DiskGrid.Columns[4].HeaderText = 'Usage'
$DiskGrid.Columns[0].FillWeight = 15
$DiskGrid.Columns[1].FillWeight = 20
$DiskGrid.Columns[2].FillWeight = 20
$DiskGrid.Columns[3].FillWeight = 20
$DiskGrid.Columns[4].FillWeight = 45
$DiskGrid.RowTemplate.Height = 34

$PanelDisks.Controls.AddRange(@($LabelDisksTitle,$ButtonRefreshDisks,$DiskGrid))
$ContentPanel.Controls.Add($PanelDisks)

$script:DiskCriticalBrush     = [SolidBrush]::new($Theme.ErrorColor)
$script:DiskHealthyBrush      = [SolidBrush]::new($Theme.SuccessColor)
$script:DiskWarningBrush      = [SolidBrush]::new($Theme.WarningColor)
$script:DiskBarBackgroundBrush = [SolidBrush]::new($Theme.BorderColor)
$script:DiskLabelTextBrush    = [SolidBrush]::new($Theme.TextColor)

$DiskGrid.Add_CellPainting({
    param([object]$Sender, [System.EventArgs]$EventArgs)
    if ($EventArgs.ColumnIndex -ne 4 -or $EventArgs.RowIndex -lt 0) { return }
    $UsedPercent = $EventArgs.Value
    if ($null -eq $UsedPercent) { return }
    $EventArgs.PaintBackground($EventArgs.CellBounds,$true)
    $Padding = 6
    $BarRectangle = [Rectangle]::new($EventArgs.CellBounds.X + $Padding, $EventArgs.CellBounds.Y + 9, $EventArgs.CellBounds.Width - ($Padding*2), 16)
    $EventArgs.Graphics.FillRectangle($script:DiskBarBackgroundBrush,$BarRectangle)
    $FillWidth = [int]($BarRectangle.Width * ($UsedPercent/100.0))
    $BarColorBrush = if ($UsedPercent -ge 90) { $script:DiskCriticalBrush } elseif ($UsedPercent -ge 75) { $script:DiskWarningBrush } else { $script:DiskHealthyBrush }
    if ($FillWidth -gt 0) { $EventArgs.Graphics.FillRectangle($BarColorBrush,[Rectangle]::new($BarRectangle.X,$BarRectangle.Y,$FillWidth,$BarRectangle.Height)) }
    $BarLabel = "$UsedPercent% used"
    $LabelSize = $EventArgs.Graphics.MeasureString($BarLabel,$Theme.RegularFont)
    $LabelPosition = [PointF]::new($BarRectangle.X + ($BarRectangle.Width - $LabelSize.Width)/2, $BarRectangle.Y + ($BarRectangle.Height - $LabelSize.Height)/2)
    $EventArgs.Graphics.DrawString($BarLabel,$Theme.RegularFont,$script:DiskLabelTextBrush,$LabelPosition)
    $EventArgs.Handled = $true
})

function Update-DiskList {
    if (-not (Test-ActiveSession)) { return }
    $CurrentServer = Get-ActiveServer
    try {
        $Disks = Get-RemoteDisks -ServerContext $CurrentServer
        $DiskGrid.SuspendLayout()
        $DiskGrid.Rows.Clear()
        foreach ($Disk in $Disks) {
            $UsedGB = [math]::Round($Disk.SizeGB - $Disk.FreeGB,1)
            $DiskGrid.Rows.Add($Disk.Drive,"$UsedGB GB","$($Disk.FreeGB) GB","$($Disk.SizeGB) GB",(100 - $Disk.Percent)) | Out-Null
        }
        $DiskGrid.ResumeLayout()
        Add-Log "Loaded disk info from $($CurrentServer.Name)" 'Success'
    } catch {
        Set-FailureStatus -LogMessage 'Failed to load disks' -ErrorRecord $_
    }
}

$ButtonRefreshDisks.Add_Click({ Invoke-Refresh -Button $ButtonRefreshDisks -CooldownKey 'Disks' -Action { Update-DiskList } })
#endregion

#region PanelRestart
$PanelRestart = New-ContentPanel
$LabelRestartTitle = New-AdminLabel -LabelText 'Server Restart' -XPosition 20 -YPosition 15 -Width 300 -Height 25 -ForegroundColor $Theme.TextColor -Font $Theme.BoldFont
$LabelRestartWarning = New-AdminLabel -LabelText "This will restart the remote server.`nType RESTART to confirm." -XPosition 20 -YPosition 55 -Width 400 -Height 40 -ForegroundColor $Theme.SecondaryTextColor
$TextBoxConfirmRestart = New-AdminTextBox -XPosition 20 -YPosition 105 -Width 200 -Height 24
$ButtonDoRestart = New-AdminButton -ButtonText 'Restart Server' -XPosition 20 -YPosition 140 -Width 150 -Height 30 -BackgroundColor $Theme.ErrorColor
$LabelRestartStatus = New-AdminLabel -LabelText '' -XPosition 20 -YPosition 180 -Width 440 -Height 100 -ForegroundColor $Theme.SecondaryTextColor

$PanelRestart.Controls.AddRange(@($LabelRestartTitle,$LabelRestartWarning,$TextBoxConfirmRestart,$ButtonDoRestart,$LabelRestartStatus))
$ContentPanel.Controls.Add($PanelRestart)
#endregion

#region Navigation
$AllPanels = @($PanelSwitch,$PanelServices,$PanelProcesses,$PanelDisks,$PanelRestart)

function Show-Panel {
    param([System.Windows.Forms.Panel]$Panel)
    foreach ($PanelItem in $AllPanels) { $PanelItem.Visible = $false }
    if ($Panel) { $Panel.Visible = $true }
}

function Set-RebootVisible {
    param([bool]$Visible)
    $LabelRebootKey.Visible = $Visible
    $LabelRebootValue.Visible = $Visible
}

function Set-RebootLabelState {
    param([bool]$Pending)
    $LabelRebootValue.Text = if ($Pending) { 'Yes' } else { 'No' }
    $LabelRebootValue.ForeColor = if ($Pending) { $Theme.ErrorColor } else { $Theme.SuccessColor }
}

function Update-RebootLabel {
    param([switch]$Force)
    $CurrentServer = Get-ActiveServer
    if (-not (Test-ActiveSession)) { if (-not $script:RestartTimer.Enabled) { Set-RebootVisible $false }; return }
    if (-not $Force -and $null -ne $CurrentServer.RebootPending) {
        Set-RebootVisible $true
        Set-RebootLabelState $CurrentServer.RebootPending
        return
    }
    Set-RebootVisible $true
    $LabelRebootValue.Text = 'Checking...'
    $LabelRebootValue.ForeColor = $Theme.SecondaryTextColor
    try {
        $RebootPending = Test-RemoteRebootPending -ServerContext $CurrentServer
        $CurrentServer.RebootPending = $RebootPending
        Set-RebootLabelState $RebootPending
    } catch {
        $CurrentServer.RebootPending = $null
        $LabelRebootValue.Text = 'Unknown'
        $LabelRebootValue.ForeColor = $Theme.WarningColor
    }
}

$script:SuppressServerListEvent = $false
$script:GuiUserName = $null

function Update-ServerList {
    $script:SuppressServerListEvent = $true
    try {
        $ListServers.Items.Clear()
        foreach ($ServerName in Get-ServerNames) { $ListServers.Items.Add($ServerName) | Out-Null }
        $ActiveServerContext = Get-ActiveServer
        if ($ActiveServerContext -and $ListServers.Items.Contains($ActiveServerContext.Name)) { $ListServers.SelectedItem = $ActiveServerContext.Name }
        elseif ($ListServers.Items.Count -gt 0) { $ListServers.SelectedIndex = 0 }
    } finally {
        $script:SuppressServerListEvent = $false
    }
}

function Update-Sidebar {
    $HasServers = @(Get-ServerNames).Count -gt 0
    $IsAuthenticated = [bool]$script:GuiUserName
    $IsConnected = Test-ActiveSession
    $IsRestarting = $script:RestartTimer.Enabled
    Update-ServerList
    $ListServers.Visible = $true
    $ListServers.Enabled = $HasServers
    foreach ($NavButton in @($ButtonNavigationServices,$ButtonNavigationProcesses,$ButtonNavigationDisks,$ButtonNavigationRestart,$ButtonDisconnect)) {
        $NavButton.Visible = $true
        Set-ButtonEnabledState $NavButton $IsConnected
    }
    $ButtonAddServer.Visible = $true
    Set-ButtonEnabledState $ButtonAddServer ($IsAuthenticated -and -not $IsRestarting)
    $ButtonSignOut.Visible = $true
    Set-ButtonEnabledState $ButtonSignOut ($IsAuthenticated -and -not $IsRestarting)
    $ShowLogin = -not $IsAuthenticated
    foreach ($LoginControl in @($LabelUser,$TextBoxUser,$LabelPass,$TextBoxPass,$ButtonLogin)) { $LoginControl.Visible = $ShowLogin }
    $LabelSignedInAs.Visible = $IsAuthenticated
    if ($IsAuthenticated) { $LabelSignedInAs.Text = "Signed in as $script:GuiUserName" }
    if ($IsConnected) { Update-RebootLabel } elseif (-not $IsRestarting) { Set-RebootVisible $false }
    $LabelLoginStatus.Visible = -not $IsAuthenticated
}
#endregion

#region ConnectHandlers
function Connect-AndTrack {
    param([string]$ServerName)
    $ServerContext = Connect-Server -ServerName $ServerName
    Add-Log "Connected to $ServerName as $script:GuiUserName via WinRM" 'Success'
    Update-Sidebar
    Show-Panel -Panel $PanelServices
    Update-ServiceList
}

$ButtonLogin.Add_Click({
    if (-not (Test-RefreshCooldown -Key 'Login' -Seconds 2)) { return }
    if (-not $TextBoxUser.Text.Trim()) { $LabelLoginStatus.Text = 'Enter a username.'; return }
    if (-not $TextBoxPass.Text) { $LabelLoginStatus.Text = 'Enter a password.'; return }

    $LabelLoginStatus.ForeColor = $Theme.SecondaryTextColor
    $LabelLoginStatus.Text = 'Signing in...'
    $ButtonLogin.Enabled = $false
    $Form.Refresh()

    try {
        $SecurePassword = New-Object System.Security.SecureString
        foreach ($Character in $TextBoxPass.Text.ToCharArray()) { $SecurePassword.AppendChar($Character) }
        $SecurePassword.MakeReadOnly()
        $UserNameInput = $TextBoxUser.Text.Trim()
        $TextBoxPass.Clear()

        $LogonToken = New-NetOnlyToken -UserName $UserNameInput -Password $SecurePassword
        $DomainName = (Split-DomainUser -UserName $UserNameInput).Domain
        if (-not (Test-NetOnlyToken -Token $LogonToken -DomainName $DomainName)) {
            $LogonToken.Dispose()
            throw 'Invalid credentials'
        }
        Set-CoreCredential -Token $LogonToken
        $script:GuiUserName = $UserNameInput
        Add-Log "Signed in as $UserNameInput" 'Success'
        $LabelLoginStatus.Text = ''
        $TextBoxUser.Text = ''
        Update-Sidebar
    } catch {
        $TextBoxUser.Text = ''
        $LabelLoginStatus.ForeColor = $Theme.ErrorColor
        $LabelLoginStatus.Text = 'Sign-in failed. Check your username/password.'
        Add-Log 'Sign-in failed: incorrect username or password' 'Fail'
    } finally {
        $ButtonLogin.Enabled = $true
    }
})

$ButtonConnectNewServer.Add_Click({
    if (-not (Test-RefreshCooldown -Key 'Switch' -Seconds 2)) { return }
    $NewServerName = $TextBoxNewServer.Text.Trim()
    if (-not $NewServerName) { $LabelSwitchStatus.Text = 'Enter a server name.'; return }
    if ($NewServerName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9\.\-]{0,253}$') { $LabelSwitchStatus.Text = 'Invalid server name.'; return }
    if (Get-ServerContext -ServerName $NewServerName) { $LabelSwitchStatus.ForeColor = $Theme.WarningColor; $LabelSwitchStatus.Text = "Already connected to $NewServerName."; return }

    $LabelSwitchStatus.ForeColor = $Theme.SecondaryTextColor
    $LabelSwitchStatus.Text = 'Connecting...'
    $ButtonConnectNewServer.Enabled = $false
    $Form.Refresh()

    try {
        Connect-AndTrack -ServerName $NewServerName
        $LabelSwitchStatus.ForeColor = $Theme.SuccessColor
        $LabelSwitchStatus.Text = "Connected to $NewServerName"
        $TextBoxNewServer.Text = ''
    } catch {
        $LabelSwitchStatus.ForeColor = $Theme.ErrorColor
        $LabelSwitchStatus.Text = if ($_.CategoryInfo.Category -eq 'LimitsExceeded') { $_.Exception.Message } else { "Could not connect: $NewServerName" }
        Add-Log "Connect failed: $NewServerName ($($_.Exception.Message))" 'Fail'
    } finally {
        $ButtonConnectNewServer.Enabled = $true
    }
})

$ButtonAddServer.Add_Click({ $TextBoxNewServer.Text = ''; $LabelSwitchStatus.Text = ''; Show-Panel -Panel $PanelSwitch })

$ButtonSignOut.Add_Click({
    $ConfirmResult = [MessageBox]::Show(
        'Sign out and disconnect from all servers?', 'Confirm Sign Out',
        [MessageBoxButtons]::YesNo, [MessageBoxIcon]::Question)
    if ($ConfirmResult -ne [DialogResult]::Yes) { return }
    foreach ($ServerName in Get-ServerNames) { Remove-ServerContext -ServerName $ServerName }
    Clear-CoreCredential
    $script:GuiUserName = $null
    $TextBoxUser.Text = ''; $TextBoxPass.Text = ''
    Add-Log 'Signed out'
    Update-Sidebar
    Show-Panel -Panel $null
})

$ButtonDisconnect.Add_Click({
    $CurrentServer = Get-ActiveServer
    if (-not $CurrentServer) { return }
    $ConfirmResult = [MessageBox]::Show(
        "Disconnect from $($CurrentServer.Name)?", 'Confirm Disconnect',
        [MessageBoxButtons]::YesNo, [MessageBoxIcon]::Question)
    if ($ConfirmResult -ne [DialogResult]::Yes) { return }
    Remove-ServerContext -ServerName $CurrentServer.Name
    Add-Log "Disconnected: $($CurrentServer.Name)"
    Update-Sidebar
    if (Get-ActiveServer) { Show-Panel -Panel $PanelServices; Update-ServiceList } else { Show-Panel -Panel $null }
})

$ListServers.Add_SelectedIndexChanged({
    if ($script:SuppressServerListEvent) { return }
    if (-not $ListServers.SelectedItem) { return }
    Set-ActiveServer -ServerName $ListServers.SelectedItem
    Update-Sidebar
    Update-RebootLabel -Force
    if ($PanelServices.Visible)   { Update-ServiceList }
    elseif ($PanelProcesses.Visible) { Update-ProcessList }
    elseif ($PanelDisks.Visible)  { Update-DiskList }
})
#endregion

#region ServiceHandlers
function Update-ServiceList {
    if (-not (Test-ActiveSession)) { return }
    $CurrentServer = Get-ActiveServer
    $LabelServiceStatus.ForeColor = $Theme.SecondaryTextColor
    $LabelServiceStatus.Text = 'Loading...'
    $Form.Refresh()

    try {
        $Services = Get-RemoteServices -ServerContext $CurrentServer
        $SortedServices = $Services | Sort-Object @{Expression={$_.State -ne 'Running'}}, Name
        $CurrentServer.Services = $SortedServices
        Set-ServiceGridRows $SortedServices
        $LabelServiceStatus.Text = "Loaded $($SortedServices.Count) services."
        Add-Log "Loaded $($SortedServices.Count) services from $($CurrentServer.Name)" 'Success'
    } catch {
        Set-FailureStatus -Label $LabelServiceStatus -LogMessage 'Failed to load services' -ErrorRecord $_
    }
}

function Set-ServiceGridRows {
    param([object[]]$ServiceRows)
    $ServiceGrid.SuspendLayout()
    $ServiceGrid.Rows.Clear()
    foreach ($Service in $ServiceRows) {
        $RowIndex = $ServiceGrid.Rows.Add($Service.Name,$Service.DisplayName,$Service.State,$Service.StartMode)
        $RowColor = switch ($Service.State) {
            'Running' { $Theme.SuccessColor }
            'Stopped' { $Theme.ErrorColor }
            default   { $Theme.WarningColor }
        }
        $ServiceGrid.Rows[$RowIndex].Cells[2].Style.ForeColor = $RowColor
    }
    $ServiceGrid.ResumeLayout()
}

Register-SearchFilter -TextBox $TextBoxServiceSearch -GetSource { param($s) $s.Services } -SetRows { param($r) Set-ServiceGridRows $r } -MatchFields @('Name','DisplayName')

$ButtonRefreshServices.Add_Click({ Invoke-Refresh -Button $ButtonRefreshServices -CooldownKey 'Services' -Action { Update-ServiceList } })

function Get-SelectedServiceName {
    if ($ServiceGrid.SelectedRows.Count -eq 0) { return $null }
    return [string]$ServiceGrid.SelectedRows[0].Cells[0].Value
}

$script:ServiceRestartTimer = New-Object System.Windows.Forms.Timer -Property @{ Interval = 2000 }
$script:ServiceRestartStopwatch = $null
$script:ServiceRestartServiceName = $null
$script:ServiceRestartServerName = $null

$script:ServiceRestartTimer.Add_Tick({
    $CurrentServer = Get-ServerContext -ServerName $script:ServiceRestartServerName
    if (-not (Test-ActiveSession -ServerContext $CurrentServer)) { $script:ServiceRestartTimer.Stop(); return }
    $ServiceStatus = $null
    try { $ServiceStatus = Get-RemoteServiceStatus -ServerContext $CurrentServer -ServiceName $script:ServiceRestartServiceName } catch {}
    if ($ServiceStatus -eq 'Running' -or $script:ServiceRestartStopwatch.Elapsed.TotalSeconds -ge 180) {
        $script:ServiceRestartTimer.Stop()
        $ActiveServer = Get-ActiveServer
        if ($ActiveServer -and $CurrentServer.Name -eq $ActiveServer.Name) {
            $LabelServiceStatus.ForeColor = $Theme.SuccessColor
            $LabelServiceStatus.Text = "$($script:ServiceRestartServiceName): $ServiceStatus"
        }
        Add-Log "Restart succeeded: $($script:ServiceRestartServiceName) on $($CurrentServer.Name)" 'Success'
        if ($PanelServices.Visible) { Update-ServiceList }
    }
})

function Invoke-ServiceAction {
    param([string]$ServiceAction)
    if (-not (Test-RefreshCooldown -Key 'SvcAction')) { return }
    $ServiceName = Get-SelectedServiceName
    if (-not $ServiceName) { $LabelServiceStatus.Text = 'Select a service.'; return }
    if ($ServiceAction -in @('Stop','Restart')) {
        $ConfirmResult = [MessageBox]::Show(
            "$ServiceAction service '$ServiceName'?", "Confirm $ServiceAction",
            [MessageBoxButtons]::YesNo, [MessageBoxIcon]::Warning)
        if ($ConfirmResult -ne [DialogResult]::Yes) { return }
    }
    $LabelServiceStatus.ForeColor = $Theme.SecondaryTextColor
    $LabelServiceStatus.Text = "$ServiceAction`: $ServiceName..."
    $Form.Refresh()
    try {
        Set-RemoteServiceState -ServerContext (Get-ActiveServer) -ServiceName $ServiceName -ServiceAction $ServiceAction
        if ($ServiceAction -eq 'Restart') {
            $script:ServiceRestartServiceName = $ServiceName
            $script:ServiceRestartServerName = (Get-ActiveServer).Name
            $script:ServiceRestartStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $script:ServiceRestartTimer.Start()
            return
        } else {
            $LabelServiceStatus.Text = "$ServiceAction succeeded: $ServiceName"
        }
        $LabelServiceStatus.ForeColor = $Theme.SuccessColor
        Add-Log "$ServiceAction succeeded: $ServiceName" 'Success'
    } catch {
        Set-FailureStatus -Label $LabelServiceStatus -LogMessage "$ServiceAction failed on $ServiceName" -ErrorRecord $_
    }
    Update-ServiceList
}

$ButtonStartService.Add_Click({ Invoke-ServiceAction -ServiceAction 'Start' })
$ButtonStopService.Add_Click({ Invoke-ServiceAction -ServiceAction 'Stop' })
$ButtonRestartService.Add_Click({ Invoke-ServiceAction -ServiceAction 'Restart' })
#endregion

#region RestartHandlers
$script:RestartTimer = New-Object System.Windows.Forms.Timer -Property @{ Interval = 5000 }
$script:RestartStopwatch = $null
$script:RestartTargetServerName = $null

$script:RestartTimer.Add_Tick({
    if ($script:RestartStopwatch.Elapsed.TotalSeconds -ge 180) {
        $script:RestartTimer.Stop()
        $LabelRestartStatus.ForeColor = $Theme.ErrorColor
        $LabelRestartStatus.Text = 'Timed out waiting for server to come back.'
        Add-Log "Timed out waiting for $($script:RestartTargetServerName) after restart" 'Fail'
        $ButtonDoRestart.Enabled = $true
        Update-Sidebar
        Show-Panel -Panel $PanelRestart
        return
    }
    try {
        Connect-Server -ServerName $script:RestartTargetServerName | Out-Null
        $script:RestartTimer.Stop()
        $LabelRestartStatus.ForeColor = $Theme.SuccessColor
        $LabelRestartStatus.Text = 'Reconnected after reboot.'
        Add-Log "Reconnected to $($script:RestartTargetServerName) after reboot" 'Success'
        Update-RebootLabel
        $ButtonDoRestart.Enabled = $true
        Update-Sidebar
        Show-Panel -Panel $PanelRestart
    } catch {
        $LabelRestartStatus.Text = "Reconnecting to $($script:RestartTargetServerName)..."
    }
})

$ButtonDoRestart.Add_Click({
    if (-not (Test-RefreshCooldown -Key 'Restart' -Seconds 3)) { return }
    if ($TextBoxConfirmRestart.Text -ne 'RESTART') {
        $LabelRestartStatus.ForeColor = $Theme.ErrorColor
        $LabelRestartStatus.Text = 'Type RESTART exactly to confirm.'
        return
    }

    $CurrentServer = Get-ActiveServer
    $script:RestartTargetServerName = $CurrentServer.Name
    $ButtonDoRestart.Enabled = $false
    try {
        Restart-RemoteServer -ServerContext $CurrentServer
        $TextBoxConfirmRestart.Text = ''
        $LabelRestartStatus.ForeColor = $Theme.WarningColor
        $LabelRestartStatus.Text = "Restart sent. Waiting for $($script:RestartTargetServerName) to come back..."
        Add-Log "Restart sent to $($script:RestartTargetServerName)"

        $script:RestartStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $script:RestartTimer.Start()
        Update-Sidebar
    } catch {
        Set-FailureStatus -Label $LabelRestartStatus -LogMessage "Restart failed on $($script:RestartTargetServerName)" -ErrorRecord $_
        $ButtonDoRestart.Enabled = $true
    }
})
#endregion

#region NavHandlers
$ButtonNavigationServices.Add_Click({ Show-Panel -Panel $PanelServices; if (Test-RefreshCooldown -Key 'Services') { Update-ServiceList } })
$ButtonNavigationProcesses.Add_Click({ Show-Panel -Panel $PanelProcesses; if (Test-RefreshCooldown -Key 'Processes') { Update-ProcessList } })
$ButtonNavigationDisks.Add_Click({ Show-Panel -Panel $PanelDisks; if (Test-RefreshCooldown -Key 'Disks') { Update-DiskList } })
$ButtonNavigationRestart.Add_Click({ if (Test-ActiveSession) { Show-Panel -Panel $PanelRestart } })
#endregion

#region Cleanup
$Form.Add_FormClosing({
    foreach ($ServerName in Get-ServerNames) { Remove-ServerContext -ServerName $ServerName }
    foreach ($Timer in @($script:RestartTimer, $script:ServiceRestartTimer)) { if ($Timer) { $Timer.Stop(); $Timer.Dispose() } }
    Clear-CoreCredential
    (@($LogEntryBrushes.Values) + @($script:DiskCriticalBrush,$script:DiskHealthyBrush,$script:DiskWarningBrush,$script:DiskBarBackgroundBrush,$script:DiskLabelTextBrush)) | ForEach-Object { $_.Dispose() }
    $Theme.RegularFont.Dispose(); $Theme.BoldFont.Dispose(); $Theme.HeaderFont.Dispose(); $ActivityLogListBox.Font.Dispose()
})

Update-Sidebar
Show-Panel -Panel $null
[System.Windows.Forms.Application]::add_ThreadException({
    param([object]$Sender, [System.EventArgs]$EventArgs)
    try { Add-Log "Unhandled UI error: $($EventArgs.Exception.Message)" 'Fail' } catch {}
})
[System.Windows.Forms.Application]::Run($Form)
$Form.Dispose()
}
#endregion

function Invoke-Refresh {
    param([System.Windows.Forms.Button]$Button, [string]$CooldownKey, [scriptblock]$Action)
    if (-not (Test-RefreshCooldown -Key $CooldownKey)) { return }
    $Button.Enabled = $false
    & $Action
    $Button.Enabled = $true
}

Export-ModuleMember -Function Show-AdminPanel