# ============================================================================
# MyGeekMac Diagnostics Script v1.0
# ============================================================================
# Collects system diagnostics and sends to n8n webhook for Claude analysis
# ============================================================================

param(
    [string]$WebhookUrl = "https://joschas-mac-mini.tail28c800.ts.net/webhook/mygeek-diagnostics"
)

# Production URL: https://joschas-mac-mini.tail28c800.ts.net/webhook/mygeek-diagnostics
# Test URL: https://joschas-mac-mini.tail28c800.ts.net/webhook-test/mygeek-diagnostics

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MyGeekMac Diagnostics v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Collecting system information..." -ForegroundColor Yellow

# Initialize diagnostics object
$diagnostics = @{
    timestamp = (Get-Date -Format "o")
    hostname = $env:COMPUTERNAME
    username = $env:USERNAME
}

# OS Information
Write-Host "  [1/8] OS info..." -ForegroundColor Gray
$os = Get-CimInstance Win32_OperatingSystem
$diagnostics.os = @{
    name = $os.Caption
    version = $os.Version
    build = $os.BuildNumber
    architecture = $os.OSArchitecture
    install_date = $os.InstallDate.ToString("o")
    last_boot = $os.LastBootUpTime.ToString("o")
}

# Hardware
Write-Host "  [2/8] Hardware..." -ForegroundColor Gray
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
$diagnostics.hardware = @{
    cpu_name = $cpu.Name
    cpu_cores = $cpu.NumberOfCores
    cpu_threads = $cpu.NumberOfLogicalProcessors
    ram_gb = [math]::Round($ram.Sum / 1GB, 2)
}

# Disk Space
Write-Host "  [3/8] Disk space..." -ForegroundColor Gray
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    @{
        drive = $_.DeviceID
        size_gb = [math]::Round($_.Size / 1GB, 2)
        free_gb = [math]::Round($_.FreeSpace / 1GB, 2)
        percent_free = [math]::Round(($_.FreeSpace / $_.Size) * 100, 1)
    }
}
$diagnostics.disks = @($disks)

# Network Adapters
Write-Host "  [4/8] Network..." -ForegroundColor Gray
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
    $ip = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    @{
        name = $_.Name
        description = $_.InterfaceDescription
        mac = $_.MacAddress
        ip = $ip.IPAddress
        speed_mbps = [math]::Round($_.LinkSpeed.Replace(' Gbps','000').Replace(' Mbps','') -as [int], 0)
    }
}
$diagnostics.network = @($adapters)

# Top Processes by Memory
Write-Host "  [5/8] Processes..." -ForegroundColor Gray
$processes = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
    @{
        name = $_.ProcessName
        pid = $_.Id
        memory_mb = [math]::Round($_.WorkingSet64 / 1MB, 2)
        cpu_seconds = [math]::Round($_.CPU, 2)
    }
}
$diagnostics.top_processes = @($processes)

# Recent Event Log Errors (last 24 hours)
Write-Host "  [6/8] Event logs..." -ForegroundColor Gray
$cutoff = (Get-Date).AddHours(-24)
$errors = Get-WinEvent -FilterHashtable @{LogName='System','Application'; Level=2; StartTime=$cutoff} -MaxEvents 20 2>$null | ForEach-Object {
    @{
        time = $_.TimeCreated.ToString("o")
        source = $_.ProviderName
        id = $_.Id
        message = $_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))
    }
}
$diagnostics.recent_errors = @($errors)

# Installed Programs (key ones)
Write-Host "  [7/8] Installed software..." -ForegroundColor Gray
$programs = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Where-Object { $_.DisplayName } |
    Select-Object DisplayName, DisplayVersion, InstallDate |
    Sort-Object DisplayName |
    Select-Object -First 30 |
    ForEach-Object {
        @{
            name = $_.DisplayName
            version = $_.DisplayVersion
        }
    }
$diagnostics.installed_programs = @($programs)

# Services Status (non-running important ones)
Write-Host "  [8/8] Services..." -ForegroundColor Gray
$important_services = @('wuauserv', 'WinDefend', 'Spooler', 'BITS', 'W32Time', 'Dhcp', 'Dnscache')
$services = Get-Service | Where-Object { $_.Name -in $important_services } | ForEach-Object {
    @{
        name = $_.Name
        display_name = $_.DisplayName
        status = $_.Status.ToString()
        start_type = $_.StartType.ToString()
    }
}
$diagnostics.services = @($services)

# Tailscale Status
$tsIP = $null
try {
    $tsIP = & tailscale ip -4 2>$null
    if ($tsIP) { $tsIP = $tsIP.Trim() }
} catch {}
$diagnostics.tailscale_ip = $tsIP

Write-Host ""
Write-Host "Diagnostics collected!" -ForegroundColor Green
Write-Host ""

# Convert to JSON
$json = $diagnostics | ConvertTo-Json -Depth 5 -Compress

# Send to webhook
Write-Host "Sending to MyGeekMac support..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $json -ContentType "application/json" -TimeoutSec 30
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  DIAGNOSTICS SENT SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Josh can now analyze your system remotely." -ForegroundColor White
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  COULD NOT SEND AUTOMATICALLY" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Saving diagnostics locally instead..." -ForegroundColor Yellow
    
    # Save locally as fallback
    $localPath = "$env:TEMP\MyGeekMac_Diagnostics.json"
    $json | Out-File -FilePath $localPath -Encoding UTF8
    
    Write-Host ""
    Write-Host "Diagnostics saved to: $localPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please send this file to Josh at josh@mygeekmac.com" -ForegroundColor White
    Write-Host ""
}

# Also display summary
Write-Host "========================================" -ForegroundColor Gray
Write-Host "  SYSTEM SUMMARY" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Gray
Write-Host "  Hostname:    $($diagnostics.hostname)" -ForegroundColor White
Write-Host "  OS:          $($diagnostics.os.name)" -ForegroundColor White
Write-Host "  RAM:         $($diagnostics.hardware.ram_gb) GB" -ForegroundColor White
Write-Host "  CPU:         $($diagnostics.hardware.cpu_name)" -ForegroundColor White
if ($diagnostics.disks.Count -gt 0) {
    Write-Host "  Disk Free:   $($diagnostics.disks[0].free_gb) GB ($($diagnostics.disks[0].percent_free)%)" -ForegroundColor White
}
if ($tsIP) {
    Write-Host "  Tailscale:   $tsIP" -ForegroundColor White
}
Write-Host "  Errors (24h): $($diagnostics.recent_errors.Count)" -ForegroundColor $(if ($diagnostics.recent_errors.Count -gt 5) { "Yellow" } else { "White" })
Write-Host "========================================" -ForegroundColor Gray
