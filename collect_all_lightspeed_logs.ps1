# ============================
# SECTION 1: Detect Agent Path
# ============================
$filterAgentPath = "C:\Program Files\Lightspeed Systems\Filter Agent"
$smartAgentPath = "C:\Program Files\Lightspeed Systems\Smart Agent"

if (Test-Path $filterAgentPath) {
    $agentPath = $filterAgentPath
} elseif (Test-Path $smartAgentPath) {
    $agentPath = $smartAgentPath
} else {
    Write-Error "❌ Neither Filter Agent nor Smart Agent directory was found."
    exit
}

# ============================================
# SECTION 2: Stop the Lightspeed Agent Service
# ============================================
Stop-Service -Name lssasvc -Force

# ============================================
# SECTION 3: Enable Service Logging via Environment Variables
# ============================================
[System.Environment]::SetEnvironmentVariable("LSSASvc", "0x3f04", "Machine")
[System.Environment]::SetEnvironmentVariable("RELAY_LOG_LEVEL", "debug", "Machine")
[System.Environment]::SetEnvironmentVariable("RELAY_LOG_SCOPES", "FilteringJS", "Machine")

# ============================================
# SECTION 4: Enable Debug Logging via Service Parameters
# ============================================
$exePath = "$agentPath\lssasvc.exe"
$debugParams = "/l /v /d /tcp /json /policy /proxy /internal"
$debugCommand = "config lssasvc binPath= `"$exePath $debugParams`""
Start-Process -FilePath "sc.exe" -ArgumentList $debugCommand -Wait -NoNewWindow

# ============================================
# SECTION 5: Restart the Agent Service
# ============================================
Start-Service -Name lssasvc

# ============================================
# SECTION 6: Prompt to Reproduce the Issue
# ============================================
Write-Host "✅ Debug and service logging enabled. Please reproduce the issue now."
Write-Host "⏸️ Press any key to continue once reproduction is complete..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ============================================
# SECTION 7: Copy Log Files to Timestamped Folder
# ============================================
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$destination = "C:\Software\Lightspeed\Log\$timestamp"
New-Item -ItemType Directory -Path $destination -Force | Out-Null

$proxyLog = Join-Path $agentPath "PolicyLogs\lsfilter.log"
$serviceLog = Join-Path $agentPath "LSSASvc.log"

Copy-Item $proxyLog -Destination $destination -ErrorAction SilentlyContinue
Copy-Item $serviceLog -Destination $destination -ErrorAction SilentlyContinue

Write-Host "📁 Logs copied to: $destination"

# ============================================
# SECTION 8: Prompt to Revert All Logging Changes
# ============================================
$revert = Read-Host "Do you want to revert all logging configurations? (Y/N)"
if ($revert -eq "Y") {
    # Revert environment variables
    [System.Environment]::SetEnvironmentVariable("LSSASvc", $null, "Machine")
    [System.Environment]::SetEnvironmentVariable("RELAY_LOG_LEVEL", $null, "Machine")
    [System.Environment]::SetEnvironmentVariable("RELAY_LOG_SCOPES", $null, "Machine")
    Write-Host "🔄 Environment variables reverted."

    # Revert debug parameters to default (/C)
    Stop-Service -Name lssasvc -Force
    $defaultParams = "/C"
    $defaultCommand = "config lssasvc binPath= `"$exePath $defaultParams`""
    Start-Process -FilePath "sc.exe" -ArgumentList $defaultCommand -Wait -NoNewWindow
    Start-Service -Name lssasvc
    Write-Host "🔄 Debug mode reverted to default (/C)."
} else {
    Write-Host "⚠️ Logging configuration remains active."
}

# ============================================
# SECTION 9: [REFERENCE ONLY] Proxy Logging via lsproxy.exe
# ============================================
<#
# This section is commented out because debug parameters already include proxy-level logging.
# You can use this if you want to manually trigger proxy logging outside of debug mode.

# Run lsproxy.exe with specific logging parameters
Set-Location $agentPath
Start-Process "lsproxy.exe" -ArgumentList '-log "cache:2,connect:1,policy:1,request:1"' -NoNewWindow -Wait
#>
