@echo off
:: ============================================================================
:: MyGeekMac Remote Support Setup
:: ============================================================================
:: Double-click this file to configure your PC for remote support.
:: No typing required - just click Yes when Windows asks for permission.
:: ============================================================================

:: Request admin elevation silently
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Run the setup
powershell -ExecutionPolicy Bypass -Command ^
$SupportPublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGrmk/vkk3GuNVBC5M6VxpxBMPzc1+MS+neCBvKqIe1r josh@mygeekmac.com'; ^
Write-Host ''; ^
Write-Host '========================================' -ForegroundColor Cyan; ^
Write-Host '  MyGeekMac Remote Support Setup' -ForegroundColor Cyan; ^
Write-Host '========================================' -ForegroundColor Cyan; ^
Write-Host ''; ^
Write-Host '[Step 1/5] Installing OpenSSH Server...' -ForegroundColor Yellow; ^
$ssh = Get-WindowsCapability -Online ^| Where-Object Name -like 'OpenSSH.Server*'; ^
if ($ssh.State -ne 'Installed') { Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 ^| Out-Null }; ^
Write-Host '[OK] OpenSSH Server ready' -ForegroundColor Green; ^
Write-Host ''; ^
Write-Host '[Step 2/5] Starting SSH service...' -ForegroundColor Yellow; ^
Set-Service -Name sshd -StartupType Automatic; ^
Start-Service sshd; ^
Write-Host '[OK] SSH service running' -ForegroundColor Green; ^
Write-Host ''; ^
Write-Host '[Step 3/5] Configuring firewall...' -ForegroundColor Yellow; ^
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue; ^
if (-not $rule) { New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 ^| Out-Null }; ^
Write-Host '[OK] Firewall configured' -ForegroundColor Green; ^
Write-Host ''; ^
Write-Host '[Step 4/5] Adding support key...' -ForegroundColor Yellow; ^
$keyDir = 'C:\ProgramData\ssh'; ^
$keyPath = 'C:\ProgramData\ssh\administrators_authorized_keys'; ^
if (-not (Test-Path $keyDir)) { New-Item -ItemType Directory -Path $keyDir -Force ^| Out-Null }; ^
$existing = Get-Content $keyPath -ErrorAction SilentlyContinue; ^
if ($existing -notmatch 'josh@mygeekmac.com') { Add-Content -Path $keyPath -Value $SupportPublicKey -Encoding ASCII }; ^
icacls $keyPath /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F' 2^>^&1 ^| Out-Null; ^
Restart-Service sshd; ^
Write-Host '[OK] Support key configured' -ForegroundColor Green; ^
Write-Host ''; ^
Write-Host '[Step 5/5] Getting connection info...' -ForegroundColor Yellow; ^
$user = $env:USERNAME; ^
$tsIP = (Get-NetIPAddress -InterfaceAlias '*Tailscale*' -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress; ^
Write-Host ''; ^
Write-Host '========================================' -ForegroundColor Green; ^
Write-Host '  SETUP COMPLETE!' -ForegroundColor Green; ^
Write-Host '========================================' -ForegroundColor Green; ^
Write-Host ''; ^
Write-Host 'Tell Josh this information:' -ForegroundColor White; ^
Write-Host ''; ^
Write-Host "  Username:     $user" -ForegroundColor Cyan; ^
if ($tsIP) { Write-Host "  Tailscale IP: $tsIP" -ForegroundColor Cyan; Write-Host ''; Write-Host "  SSH Command:  ssh `"$user`"@$tsIP" -ForegroundColor Yellow } else { Write-Host '  Tailscale:    NOT CONNECTED' -ForegroundColor Red; Write-Host ''; Write-Host '  Please install Tailscale first!' -ForegroundColor Yellow }; ^
Write-Host ''; ^
Write-Host '========================================' -ForegroundColor Green

echo.
echo Setup complete! Tell Josh the information shown above.
echo.
pause
