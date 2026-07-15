Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -Namespace Native -Name Auth -MemberDefinition @'
[DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, out Microsoft.Win32.SafeHandles.SafeAccessTokenHandle phToken);
'@

function Split-DomainUser {
    param([string]$UserName)
    $DomainName = $env:USERDOMAIN
    $AccountName = $UserName
    if ($UserName -match '@') { $AccountName, $DomainName = $UserName -split '@', 2 }
    elseif ($UserName -match '\\') { $DomainName, $AccountName = $UserName -split '\\', 2 }
    [pscustomobject]@{ User = $AccountName; Domain = $DomainName }
}

function ConvertFrom-SecurePlain {
    param([securestring]$Password, [scriptblock]$Action)
    $Ptr = [Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($Password)
    try { & $Action ([Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($Ptr) }
}

function New-NetOnlyToken {
    param([string]$UserName, [securestring]$Password)
    if (-not $Password) { throw 'Password is required' }
    $LOGON32_LOGON_NEW_CREDENTIALS = 9
    $LOGON32_PROVIDER_WINNT50      = 3
    $DomainAccountInfo = Split-DomainUser -UserName $UserName
    ConvertFrom-SecurePlain -Password $Password -Action {
        param($PlainTextPassword)
        $LogonToken = $null
        if (-not [Native.Auth]::LogonUser($DomainAccountInfo.User, $DomainAccountInfo.Domain, $PlainTextPassword, $LOGON32_LOGON_NEW_CREDENTIALS, $LOGON32_PROVIDER_WINNT50, [ref]$LogonToken)) {
            throw "LogonUser failed (Win32 $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
        }
        $LogonToken
    }
}

function Test-NetOnlyToken {
    param([Microsoft.Win32.SafeHandles.SafeAccessTokenHandle]$Token, [string]$DomainName)
    try {
        Invoke-AsNetOnly -Token $Token -ArgumentList @($DomainName) -ScriptBlock {
            param($DomainName)
            [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain(
                (New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext('Domain', $DomainName))) | Out-Null
        }
        $true
    } catch { $false }
}

function Invoke-AsNetOnly {
    param([Microsoft.Win32.SafeHandles.SafeAccessTokenHandle]$Token, [scriptblock]$ScriptBlock, [object[]]$ArgumentList)
    $ResultBox = [object[]]::new(1)
    $ErrorBox = [object[]]::new(1)
    $Action = { try { $ResultBox[0] = & $ScriptBlock @ArgumentList } catch { $ErrorBox[0] = $_ } }.GetNewClosure()
    [System.Security.Principal.WindowsIdentity]::RunImpersonated($Token, [Action]$Action)
    if ($ErrorBox[0]) { throw $ErrorBox[0] }
    return $ResultBox[0]
}

$script:ServerContexts             = [ordered]@{}
$script:ActiveServerName           = $null
$script:AuthToken                  = $null
$script:LastSessionCheckTimestamps = @{}
$script:LastSessionCheckResults    = @{}
$script:LastRefreshTimestamps      = @{}
$script:MaxConcurrentServers       = 10

function New-ServerContext {
    param([string]$ServerName)
    [pscustomobject]@{ Name = $ServerName; Session = $null; RebootPending = $null; Services = @(); Processes = @(); Connected = $false }
}

function Set-CoreCredential {
    param([Microsoft.Win32.SafeHandles.SafeAccessTokenHandle]$Token)
    if ($script:AuthToken -and -not $script:AuthToken.IsClosed) { $script:AuthToken.Dispose() }
    $script:AuthToken = $Token
}

function Clear-CoreCredential {
    if ($script:AuthToken -and -not $script:AuthToken.IsClosed) { $script:AuthToken.Dispose() }
    $script:AuthToken = $null
}
function Get-ActiveServer { if ($script:ActiveServerName) { $script:ServerContexts[$script:ActiveServerName] } }
function Get-ServerContext { param([string]$ServerName) $script:ServerContexts[$ServerName] }
function Set-ActiveServer { param([string]$ServerName) $script:ActiveServerName = $ServerName }
function Get-ServerNames { @($script:ServerContexts.Keys) }

function Remove-ServerContext {
    param([string]$ServerName)
    $ServerContext = $script:ServerContexts[$ServerName]
    if ($ServerContext) {
        if ($ServerContext.Session) { Remove-PSSession $ServerContext.Session -ErrorAction SilentlyContinue }
        $script:ServerContexts.Remove($ServerName)
        $script:LastSessionCheckTimestamps.Remove($ServerName)
        $script:LastSessionCheckResults.Remove($ServerName)
    }
    if ($script:ActiveServerName -eq $ServerName) { $script:ActiveServerName = Get-ServerNames | Select-Object -First 1 }
}

function Test-RefreshCooldown {
    param([string]$Key, [int]$Seconds = 2)
    if ($script:LastRefreshTimestamps.ContainsKey($Key) -and ([datetime]::Now - $script:LastRefreshTimestamps[$Key]).TotalSeconds -lt $Seconds) { return $false }
    $script:LastRefreshTimestamps[$Key] = [datetime]::Now
    return $true
}

function Test-ActiveSession {
    param([pscustomobject]$ServerContext = (Get-ActiveServer))
    if (-not $ServerContext -or -not $ServerContext.Connected) { return $false }
    $ServerKey = $ServerContext.Name
    $LastCheckTime = $script:LastSessionCheckTimestamps[$ServerKey]
    if ($LastCheckTime -and ([datetime]::Now - $LastCheckTime).TotalSeconds -lt 5) { return $script:LastSessionCheckResults[$ServerKey] }
    $script:LastSessionCheckTimestamps[$ServerKey] = [datetime]::Now
    try {
        Invoke-Command -Session $ServerContext.Session -ScriptBlock { $true } -ErrorAction Stop | Out-Null
        $script:LastSessionCheckResults[$ServerKey] = $true
    } catch { $script:LastSessionCheckResults[$ServerKey] = $false }
    return $script:LastSessionCheckResults[$ServerKey]
}

function Connect-Server {
    param([string]$ServerName)
    $ServerContext = $script:ServerContexts[$ServerName]
    $IsNewServer = -not $ServerContext
    if ($IsNewServer -and @($script:ServerContexts.Keys).Count -ge $script:MaxConcurrentServers) {
        throw [System.Management.Automation.ErrorRecord]::new(
            [Exception]::new("Connection limit reached ($($script:MaxConcurrentServers) servers). Disconnect one before adding another."),
            'ConnectServer.LimitReached', [System.Management.Automation.ErrorCategory]::LimitsExceeded, $ServerName)
    }
    if ($IsNewServer) {
        $ServerContext = New-ServerContext -ServerName $ServerName
        $script:ServerContexts[$ServerName] = $ServerContext
    }
    try {
        $SessionOptions = New-PSSessionOption -OpenTimeout 15000 -OperationTimeout 30000 -CancelTimeout 5000
        $RemoteSession = Invoke-AsNetOnly -Token $script:AuthToken -ArgumentList @($ServerName, $SessionOptions) -ScriptBlock {
            param($ServerName, $SessionOptions) New-PSSession -ComputerName $ServerName -Authentication Kerberos -SessionOption $SessionOptions -ErrorAction Stop
        }
        if ($ServerContext.Session) { Remove-PSSession $ServerContext.Session -ErrorAction SilentlyContinue }
        $ServerContext.Session = $RemoteSession
    } catch {
        $ServerContext.Connected = $false
        if ($IsNewServer) { $script:ServerContexts.Remove($ServerName) }
        $FailureReason = switch ($_.Exception) {
            { $_ -is [System.Management.Automation.Remoting.PSRemotingTransportException] -and $_.Message -match 'Access is denied|401|403' } { 'Auth'; break }
            { $_ -is [System.Management.Automation.Remoting.PSRemotingTransportException] } { 'Connectivity'; break }
            default { 'Unknown' }
        }
        throw [System.Management.Automation.ErrorRecord]::new(
            [Exception]::new("Connect to '$ServerName' failed ($FailureReason): $($_.Exception.Message)", $_.Exception),
            "ConnectServer.$FailureReason", [System.Management.Automation.ErrorCategory]::ConnectionError, $ServerName)
    }
    $ServerContext.Connected = $true
    $ServerContext.RebootPending = $null
    $script:ActiveServerName = $ServerName
    try { $ServerContext.RebootPending = Test-RemoteRebootPending -ServerContext $ServerContext } catch {}
    $ServerContext
}

function Get-RemoteServices {
    param([pscustomobject]$ServerContext)
    Invoke-Command -Session $ServerContext.Session -ErrorAction Stop -ScriptBlock {
        Get-CimInstance Win32_Service -Property Name, DisplayName, State, StartMode | Select-Object Name, DisplayName, State, StartMode
    }
}

function Set-RemoteServiceState {
    param([pscustomobject]$ServerContext, [string]$ServiceName, [string]$ServiceAction)
    Invoke-Command -Session $ServerContext.Session -ArgumentList $ServiceName, $ServiceAction -ErrorAction Stop -ScriptBlock {
        param($ServiceName, $ServiceAction)
        switch ($ServiceAction) {
            'Start'   { Start-Service -Name $ServiceName -ErrorAction Stop }
            'Stop'    { Stop-Service -Name $ServiceName -Force -ErrorAction Stop }
            'Restart' { Restart-Service -Name $ServiceName -Force -ErrorAction Stop }
        }
    }
}

function Get-RemoteServiceStatus {
    param([pscustomobject]$ServerContext, [string]$ServiceName)
    Invoke-Command -Session $ServerContext.Session -ArgumentList $ServiceName -ErrorAction Stop -ScriptBlock {
        param($ServiceName) (Get-Service -Name $ServiceName).Status
    }
}

function Get-RemoteProcesses {
    param([pscustomobject]$ServerContext)
    Invoke-Command -Session $ServerContext.Session -ErrorAction Stop -ScriptBlock {
        Get-Process | Sort-Object CPU -Descending | Select-Object Id, Name, @{N = 'CPU'; E = { [math]::Round($_.CPU, 1) } }, @{N = 'MemoryMB'; E = { [math]::Round($_.WorkingSet64 / 1MB, 1) } }
    }
}

function Stop-RemoteProcess {
    param([pscustomobject]$ServerContext, [int]$ProcessId)
    Invoke-Command -Session $ServerContext.Session -ArgumentList $ProcessId -ErrorAction Stop -ScriptBlock {
        param($ProcessId) Stop-Process -Id $ProcessId -Force -ErrorAction Stop
    }
}

function Get-RemoteDisks {
    param([pscustomobject]$ServerContext)
    Invoke-Command -Session $ServerContext.Session -ErrorAction Stop -ScriptBlock {
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            [pscustomobject]@{
                Drive   = $_.DeviceID
                SizeGB  = [math]::Round($_.Size / 1GB, 1)
                FreeGB  = [math]::Round($_.FreeSpace / 1GB, 1)
                Percent = if ($_.Size) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 0) } else { 0 }
            }
        }
    }
}

function Test-RemoteRebootPending {
    param([pscustomobject]$ServerContext)
    $RegistryKeyPaths = @(
        'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    )
    Invoke-Command -Session $ServerContext.Session -ErrorAction Stop -ScriptBlock {
        $RebootPendingFlag = $false
        $using:RegistryKeyPaths | ForEach-Object { if (Test-Path "HKLM:\$_") { $RebootPendingFlag = $true } }
        try {
            if ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction Stop).PendingFileRenameOperations) { $RebootPendingFlag = $true }
        } catch [System.Management.Automation.ItemNotFoundException] {
        } catch [System.Management.Automation.PSArgumentException] {}
        $RebootPendingFlag
    }
}

function Restart-RemoteServer {
    param([pscustomobject]$ServerContext)
    try { Invoke-Command -Session $ServerContext.Session -ScriptBlock { Restart-Computer -Force } -ErrorAction Stop }
    catch [System.Management.Automation.Remoting.PSRemotingTransportException] {
        # Expected: session drops as the remote host reboots; the command was already delivered.
    }
    Remove-PSSession $ServerContext.Session -ErrorAction SilentlyContinue
    $ServerContext.Session = $null
    $ServerContext.Connected = $false
}

Export-ModuleMember -Function New-NetOnlyToken, Test-NetOnlyToken, Invoke-AsNetOnly, Split-DomainUser,
    Set-CoreCredential, Clear-CoreCredential, Get-ActiveServer, Get-ServerContext,
    Set-ActiveServer, Get-ServerNames, Remove-ServerContext, Test-RefreshCooldown, Test-ActiveSession,
    Connect-Server, Get-RemoteServices, Set-RemoteServiceState, Get-RemoteServiceStatus,
    Get-RemoteProcesses, Stop-RemoteProcess, Get-RemoteDisks, Test-RemoteRebootPending, Restart-RemoteServer