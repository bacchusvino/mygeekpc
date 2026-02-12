# ============================================================================
# MyGeekMac Remote Support Setup v2.1
# ============================================================================
# Fixes: Tailscale-only firewall, error handling, admin verification, logging
# ============================================================================

$ErrorActionPreference = "Stop"
$SupportKeys = @(
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrmk/vkk3GuNVBC5M6VxpxBMPzc1+MS+neCBvKqIe1r josh@mygeekmac.com',
    'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDioCcFWEMgkKBZgs5D320aLqASzRWlt8vuz+HiQ3GSY joschapirtle@Joschas-Mini.lan'
)
$KeyFingerprints = @(
    'AAAAC3NzaC1lZDI1NTE5AAAAIGrmk/vkk3GuNVBC5M6VxpxBMPzc1\+MS\+neCBvKqIe1r',
    'AAAAC3NzaC1lZDI1NTE5AAAAIDioCcFWEMgkKBZgs5D320aLqASzRWlt8vuz\+HiQ3GSY'
)
$FirewallRuleName = 'OpenSSH-Server-Tailscale-MyGeekMac'
$LogPath = "$env:TEMP\MyGeekMac_Setup.log"
$FailCount = 0

# Start logging
Start-Transcript -Path $LogPath -Force | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[FAILED] $Message" -ForegroundColor Red
    $script:FailCount++
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyGeekMac Remote Support Setup v2.1" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Log file: $LogPath" -ForegroundColor Gray

try {

# ============================================================================
# STEP 0: Verify current user is an administrator
# ============================================================================
Write-Step "[Step 0/6] Verifying admin privileges..."

$currentUser = $env:USERNAME
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-OK "User '$currentUser' has admin privileges"
} else {
    Write-Fail "User '$currentUser' is NOT an administrator - SSH key auth may not work"
    Write-Host "  The SSH key is installed for admin accounts only." -ForegroundColor Yellow
}

# ============================================================================
# STEP 1: Install OpenSSH Server
# ============================================================================
Write-Step "[Step 1/6] Installing OpenSSH Server..."

try {
    $ssh = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    if ($ssh.State -eq 'Installed') {
        Write-OK "OpenSSH Server already installed"
    } else {
        $result = Add-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0"
        if ($result.RestartNeeded) {
            Write-Host "[WARNING] Reboot may be required to complete installation" -ForegroundColor Yellow
        }
        Write-OK "OpenSSH Server installed"
    }
} catch {
    Write-Fail "Could not install OpenSSH Server: $_"
}

# ============================================================================
# STEP 2: Start SSH service
# ============================================================================
Write-Step "[Step 2/6] Starting SSH service..."

try {
    Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
    Start-Service sshd -ErrorAction Stop
    Start-Sleep -Seconds 2
    
    $svc = Get-Service sshd
    if ($svc.Status -eq 'Running') {
        Write-OK "SSH service running"
    } else {
        Write-Fail "SSH service status: $($svc.Status)"
    }
} catch {
    Write-Fail "Could not start SSH service: $_"
}

# ============================================================================
# STEP 3: Configure firewall (TAILSCALE ONLY)
# ============================================================================
Write-Step "[Step 3/6] Configuring firewall (Tailscale only)..."

try {
    # Remove old MyGeekMac rule if it exists
    $oldRule = Get-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue
    if ($oldRule) {
        Remove-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue
        Write-Host "  Removed old firewall rule" -ForegroundColor Gray
    }
    
    # Find Tailscale interface (take first one if multiple)
    $tsInterface = Get-NetAdapter | Where-Object { 
        $_.InterfaceDescription -like '*Tailscale*' -or $_.Name -like '*Tailscale*' 
    } | Select-Object -First 1
    
    if ($tsInterface) {
        # Create rule restricted to Tailscale interface
        New-NetFirewallRule -Name $FirewallRuleName `
            -DisplayName 'OpenSSH Server (Tailscale Only - MyGeekMac)' `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22 `
            -InterfaceAlias $tsInterface.Name `
            -ErrorAction Stop | Out-Null
        Write-OK "Firewall configured - SSH allowed ONLY on Tailscale ($($tsInterface.Name))"
    } else {
        Write-Fail "Tailscale network adapter not found - firewall rule NOT created"
        Write-Host "  Install Tailscale first, then re-run this script" -ForegroundColor Yellow
    }
} catch {
    Write-Fail "Could not configure firewall: $_"
}

# ============================================================================
# STEP 4: Add support key with proper permissions
# ============================================================================
Write-Step "[Step 4/6] Adding support key..."

$keyDir = 'C:\ProgramData\ssh'
$keyPath = 'C:\ProgramData\ssh\administrators_authorized_keys'

try {
    # Create directory if needed
    if (-not (Test-Path $keyDir)) {
        New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
    }
    
    # Check and add each support key
    $existing = Get-Content $keyPath -ErrorAction SilentlyContinue
    $keysAdded = 0
    foreach ($i in 0..($SupportKeys.Count - 1)) {
        $key = $SupportKeys[$i]
        $fp = $KeyFingerprints[$i]
        if ($existing -and $existing -match $fp) {
            Write-Host "  Key $($i+1) already installed" -ForegroundColor Gray
        } else {
            Add-Content -Path $keyPath -Value $key -Encoding ASCII -ErrorAction Stop
            $keysAdded++
        }
    }
    if ($keysAdded -gt 0) {
        Write-OK "$keysAdded support key(s) added"
    } else {
        Write-OK "All support keys already installed"
    }
    
    # Set permissions (critical for SSH to accept the key)
    $icaclsResult = icacls $keyPath /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Could not set key file permissions: $icaclsResult"
    } else {
        Write-Host "  Key file permissions set correctly" -ForegroundColor Gray
    }
    
    # Restart SSH to pick up key changes
    Restart-Service sshd -ErrorAction Stop
    Start-Sleep -Seconds 2
    
} catch {
    Write-Fail "Could not configure support key: $_"
}

# ============================================================================
# STEP 5: Verify SSH is actually listening
# ============================================================================
Write-Step "[Step 5/6] Verifying SSH is listening..."

try {
    $listening = Get-NetTCPConnection -LocalPort 22 -State Listen -ErrorAction SilentlyContinue
    if ($listening) {
        Write-OK "SSH is listening on port 22"
    } else {
        Write-Fail "SSH is NOT listening on port 22"
    }
} catch {
    Write-Fail "Could not verify SSH listener: $_"
}

# ============================================================================
# STEP 6: Get connection info
# ============================================================================
Write-Step "[Step 6/6] Getting connection info..."

# Get Tailscale IP (try multiple methods)
$tsIP = $null

# Method 1: tailscale CLI
try {
    $tsIP = & tailscale ip -4 2>$null
    if ($tsIP) { $tsIP = $tsIP.Trim() }
} catch {}

# Method 2: Network adapter
if (-not $tsIP) {
    $tsIP = (Get-NetIPAddress -InterfaceAlias '*Tailscale*' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
}

# Get admin accounts for SSH
$adminAccounts = @()
try {
    $adminAccounts = (Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop | 
        Where-Object { $_.ObjectClass -eq 'User' }).Name | 
        ForEach-Object { $_.Split('\')[-1] }
} catch {
    $adminAccounts = @($currentUser)
}

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Yellow" })
if ($FailCount -eq 0) {
    Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
} else {
    Write-Host "  SETUP COMPLETED WITH $FailCount WARNING(S)" -ForegroundColor Yellow
}
Write-Host "========================================" -ForegroundColor $(if ($FailCount -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($tsIP) {
    Write-Host "Tell Josh this information:" -ForegroundColor White
    Write-Host ""
    Write-Host "  Tailscale IP: $tsIP" -ForegroundColor Cyan
    if ($adminAccounts.Count -gt 0) {
        Write-Host "  Admin users:  $($adminAccounts -join ', ')" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  SSH Command:  ssh $($adminAccounts[0])@$tsIP" -ForegroundColor Yellow
    } else {
        Write-Host "  Admin users:  (could not detect)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  SSH Command:  ssh <username>@$tsIP" -ForegroundColor Yellow
    }
    Write-Host ""
} else {
    Write-Host "  Tailscale: NOT DETECTED" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Tailscale must be installed and connected!" -ForegroundColor Yellow
    Write-Host "  Download from: https://tailscale.com/download" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  After installing Tailscale, re-run this script." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Gray
Write-Host "  Log saved to: $LogPath" -ForegroundColor Gray
Write-Host "  To remove access later, run: MyGeekMac_Remove.bat" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Gray

} finally {
    Stop-Transcript | Out-Null
}
