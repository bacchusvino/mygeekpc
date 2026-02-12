# ============================================================================
# MyGeekMac Quick Connect v1.0
# ============================================================================
# ONE SCRIPT - Installs Tailscale, joins Josh's network, enables SSH
# Client pastes ONE command, done in 2 minutes, no passwords needed
# ============================================================================

$ErrorActionPreference = "Stop"

# ============================================================================
# CONFIGURATION - Josh updates these
# ============================================================================
# Generate auth key at: https://login.tailscale.com/admin/settings/keys
# Settings: Reusable, 90 days, Pre-approved
$TailscaleAuthKey = $env:MYGEEK_TS_KEY  # Set via environment or pass as parameter

$SupportKeys = @(
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrmk/vkk3GuNVBC5M6VxpxBMPzc1+MS+neCBvKqIe1r josh@mygeekmac.com',
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDioCcFWEMgkKBZgs5D320aLqASzRWlt8vuz+HiQ3GSY joschapirtle@Joschas-Mini.lan'
)
$FirewallRuleName = 'OpenSSH-Server-Tailscale-MyGeekMac'
$LogPath = "C:\MyGeekMac_QuickConnect.log"

# ============================================================================
# START
# ============================================================================
Start-Transcript -Path $LogPath -Force | Out-Null

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  MyGeekMac Quick Connect" -ForegroundColor Cyan
Write-Host "  One script - Full remote support setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check admin
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[ERROR] Must run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Stop-Transcript | Out-Null
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================================================
# STEP 1: Install Tailscale
# ============================================================================
Write-Host "[1/5] Installing Tailscale..." -ForegroundColor Yellow

$tailscaleInstalled = Get-Command tailscale -ErrorAction SilentlyContinue
if ($tailscaleInstalled) {
    Write-Host "      Tailscale already installed" -ForegroundColor Green
} else {
    Write-Host "      Downloading Tailscale installer..." -ForegroundColor Gray
    $installerPath = "$env:TEMP\tailscale-setup.exe"
    
    try {
        # Download latest Tailscale installer
        Invoke-WebRequest -Uri "https://pkgs.tailscale.com/stable/tailscale-setup-latest.exe" -OutFile $installerPath -UseBasicParsing
        
        Write-Host "      Running installer (silent)..." -ForegroundColor Gray
        Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
        
        # Wait for Tailscale service to be ready
        Start-Sleep -Seconds 5
        
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-Host "      Tailscale installed!" -ForegroundColor Green
    } catch {
        Write-Host "      [ERROR] Failed to install Tailscale: $_" -ForegroundColor Red
        Stop-Transcript | Out-Null
        Read-Host "Press Enter to exit"
        exit 1
    }
}

# ============================================================================
# STEP 2: Connect to Josh's Tailscale network
# ============================================================================
Write-Host "[2/5] Connecting to support network..." -ForegroundColor Yellow

try {
    # Check if already connected
    $status = & "C:\Program Files\Tailscale\tailscale.exe" status 2>&1
    if ($status -match "100\.") {
        Write-Host "      Already connected to Tailscale" -ForegroundColor Green
    } else {
        Write-Host "      Authenticating (no browser needed)..." -ForegroundColor Gray
        & "C:\Program Files\Tailscale\tailscale.exe" up --authkey=$TailscaleAuthKey --reset 2>&1
        Start-Sleep -Seconds 3
        Write-Host "      Connected to support network!" -ForegroundColor Green
    }
} catch {
    Write-Host "      [ERROR] Failed to connect: $_" -ForegroundColor Red
}

# ============================================================================
# STEP 3: Install OpenSSH Server
# ============================================================================
Write-Host "[3/5] Installing SSH Server..." -ForegroundColor Yellow

try {
    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($ssh.State -eq 'Installed') {
        Write-Host "      SSH Server already installed" -ForegroundColor Green
    } else {
        Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" | Out-Null
        Write-Host "      SSH Server installed!" -ForegroundColor Green
    }
    
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd
} catch {
    Write-Host "      [ERROR] SSH install failed: $_" -ForegroundColor Red
}

# ============================================================================
# STEP 4: Configure firewall & SSH key
# ============================================================================
Write-Host "[4/5] Configuring security..." -ForegroundColor Yellow

try {
    # Remove old rule if exists
    Remove-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue
    
    # Find Tailscale adapter
    $tsAdapter = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*Tailscale*' } | Select-Object -First 1
    
    if ($tsAdapter) {
        New-NetFirewallRule -Name $FirewallRuleName `
            -DisplayName 'OpenSSH Server (Tailscale Only - MyGeekMac)' `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow `
            -LocalPort 22 -InterfaceAlias $tsAdapter.Name | Out-Null
        Write-Host "      Firewall: SSH allowed only via Tailscale" -ForegroundColor Green
    }
    
    # Add SSH key
    $keyPath = 'C:\ProgramData\ssh\administrators_authorized_keys'
    $keyDir = 'C:\ProgramData\ssh'
    
    if (-not (Test-Path $keyDir)) { New-Item -ItemType Directory -Path $keyDir -Force | Out-Null }
    
    $existing = Get-Content $keyPath -ErrorAction SilentlyContinue
    foreach ($key in $SupportKeys) {
        $keyId = ($key -split ' ')[-1]
        if (-not ($existing -match [regex]::Escape(($key -split ' ')[1]))) {
            Add-Content -Path $keyPath -Value $key -Encoding ASCII
            Write-Host "      Added key: $keyId" -ForegroundColor Gray
        }
    }
    
    icacls $keyPath /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' | Out-Null
    Restart-Service sshd
    
    Write-Host "      SSH key configured!" -ForegroundColor Green
} catch {
    Write-Host "      [ERROR] Security config failed: $_" -ForegroundColor Red
}

# ============================================================================
# STEP 5: Get connection info
# ============================================================================
Write-Host "[5/5] Getting connection info..." -ForegroundColor Yellow

$tsIP = $null
try {
    $tsIP = & "C:\Program Files\Tailscale\tailscale.exe" ip -4 2>$null
    if ($tsIP) { $tsIP = $tsIP.Trim() }
} catch {}

$hostname = $env:COMPUTERNAME
$adminUsers = @()
try {
    $adminUsers = (Get-LocalGroupMember -Group 'Administrators' | Where-Object { $_.ObjectClass -eq 'User' }).Name | ForEach-Object { $_.Split('\')[-1] }
} catch {
    $adminUsers = @($env:USERNAME)
}

# ============================================================================
# DONE - Show results
# ============================================================================
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

if ($tsIP) {
    Write-Host "  TELL JOSH:" -ForegroundColor White
    Write-Host ""
    Write-Host "  Computer: $hostname" -ForegroundColor Cyan
    Write-Host "  IP:       $tsIP" -ForegroundColor Cyan
    Write-Host "  User:     $($adminUsers -join ', ')" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Josh will connect with:" -ForegroundColor Gray
    Write-Host "  ssh $($adminUsers[0])@$tsIP" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "  [WARNING] Could not get Tailscale IP" -ForegroundColor Yellow
    Write-Host "  Tailscale may need a moment to connect." -ForegroundColor Yellow
    Write-Host "  Try: tailscale ip" -ForegroundColor Gray
}

Write-Host "================================================" -ForegroundColor Green
Write-Host "  Log: $LogPath" -ForegroundColor Gray
Write-Host "================================================" -ForegroundColor Green
Write-Host ""

Stop-Transcript | Out-Null
Read-Host "Press Enter to close"
