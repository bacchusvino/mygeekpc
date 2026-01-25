@echo off
:: ============================================================================
:: MyGeekMac Remote Support REMOVAL v2.1
:: ============================================================================
:: Run this to revoke remote support access.
:: ============================================================================

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -ExecutionPolicy Bypass -Command ^
$KeyFingerprint = 'AAAAC3NzaC1lZDI1NTE5AAAAIGrmk/vkk3GuNVBC5M6VxpxBMPzc1\+MS\+neCBvKqIe1r'; ^
$FirewallRuleName = 'OpenSSH-Server-Tailscale-MyGeekMac'; ^
$FailCount = 0; ^
Write-Host ''; ^
Write-Host '========================================' -ForegroundColor Cyan; ^
Write-Host '  MyGeekMac Access Removal v2.1' -ForegroundColor Cyan; ^
Write-Host '========================================' -ForegroundColor Cyan; ^
Write-Host ''; ^
Write-Host 'Removing support access...' -ForegroundColor Yellow; ^
$keyPath = 'C:\ProgramData\ssh\administrators_authorized_keys'; ^
try { ^
    if (Test-Path $keyPath) { ^
        $content = Get-Content $keyPath; ^
        $newContent = $content ^| Where-Object { $_ -notmatch $KeyFingerprint }; ^
        if ($newContent) { ^
            Set-Content -Path $keyPath -Value $newContent -Encoding ASCII -ErrorAction Stop ^
        } else { ^
            Remove-Item $keyPath -Force -ErrorAction Stop ^
        }; ^
        Write-Host '[OK] Support key removed' -ForegroundColor Green ^
    } else { ^
        Write-Host '[OK] No support key found' -ForegroundColor Green ^
    } ^
} catch { ^
    Write-Host \"[FAILED] Could not remove key: $_\" -ForegroundColor Red; ^
    $FailCount++ ^
}; ^
Write-Host ''; ^
Write-Host 'Removing firewall rule...' -ForegroundColor Yellow; ^
try { ^
    $rule = Get-NetFirewallRule -Name $FirewallRuleName -ErrorAction SilentlyContinue; ^
    if ($rule) { ^
        Remove-NetFirewallRule -Name $FirewallRuleName -ErrorAction Stop; ^
        Write-Host '[OK] Firewall rule removed' -ForegroundColor Green ^
    } else { ^
        Write-Host '[OK] No firewall rule found' -ForegroundColor Green ^
    } ^
} catch { ^
    Write-Host \"[FAILED] Could not remove firewall rule: $_\" -ForegroundColor Red; ^
    $FailCount++ ^
}; ^
Write-Host ''; ^
if ($FailCount -eq 0) { ^
    Write-Host '========================================' -ForegroundColor Green; ^
    Write-Host '  ACCESS REVOKED' -ForegroundColor Green; ^
    Write-Host '========================================' -ForegroundColor Green ^
} else { ^
    Write-Host '========================================' -ForegroundColor Yellow; ^
    Write-Host '  COMPLETED WITH ERRORS' -ForegroundColor Yellow; ^
    Write-Host '========================================' -ForegroundColor Yellow ^
}; ^
Write-Host ''; ^
Write-Host 'Remote support access has been removed.' -ForegroundColor White; ^
Write-Host 'SSH service is still running for your own use.' -ForegroundColor Gray; ^
Write-Host 'To fully disable SSH: Stop-Service sshd; Set-Service sshd -StartupType Disabled' -ForegroundColor Gray; ^
Write-Host ''

echo.
pause
