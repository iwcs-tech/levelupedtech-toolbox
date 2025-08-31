<#
Requires: Microsoft Graph PowerShell SDK
Run in PowerShell 7+ if possible.
#>

# -----------------------------
# 0) Install/Import & Connect
# -----------------------------
# Install-Module Microsoft.Graph -Scope AllUsers     # (once per machine / as needed)
Import-Module Microsoft.Graph.Users

# Sign in with permission to update users
$scopes = @('User.ReadWrite.All')
Connect-MgGraph -Scopes $scopes
# Select-MgProfile -Name 'v1.0'   # default, but explicit is fine (removed because it threw an error. not needed on Graph SDK v2+.) 
# -----------------------------
# 1) Parameters
# -----------------------------
# $Prefix = '30'                  # UPN prefix to target

$Prefix = (Read-Host "Enter UPN prefix to target for student grade level (e.g. 30)").Trim()
if (-not $Prefix) { Write-Host "No prefix entered. Exiting." -ForegroundColor Yellow; return }

$MembersOnly = $false           # set $true to exclude Guests
$PreviewOnly = $false            # set $false to APPLY changes

# -----------------------------
# 2) Query target users
#    Server-side filter on UPN prefix
# -----------------------------
# Note: OData 'startswith' is supported for string properties like userPrincipalName.
# This keeps the result set small & efficient.
$filter = "startswith(userPrincipalName,'$Prefix')"

$users = Get-MgUser -All -Filter $filter -Property "id,displayName,userPrincipalName,userType,ageGroup,consentProvidedForMinor"

if ($MembersOnly) {
    $users = $users | Where-Object { $_.UserType -eq 'Member' }
}

# -----------------------------
# 3) Preview & Export (safe)
# -----------------------------
$preview = $users |
    Select-Object DisplayName, UserPrincipalName, UserType, Id, AgeGroup, ConsentProvidedForMinor

if (-not $preview) {
    Write-Host "No users found with UPN starting with '$Prefix'." -ForegroundColor Yellow
    return
}

Write-Host "Preview users to be UPDATED (AgeGroup='minor', ConsentProvidedForMinor='granted')" -ForegroundColor Cyan
$preview | Format-Table -AutoSize

# Turned off export a record of who will be changed. We have the preview and don't likely need a csv everytime.
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
# $exportPath = ".\users-to-update-$($Prefix)-$stamp.csv"
# $preview | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
# Write-Host "Exported preview to $exportPath" -ForegroundColor Green




if ($PreviewOnly) {
    Write-Host "`nPreviewOnly is ON. No changes made. Set `$PreviewOnly = `$false to apply." -ForegroundColor Yellow
    return
}

# -----------------------------
# 4) APPLY updates
# -----------------------------

$proceed = Read-Host "Do you want to proceed with these changes? (Case-sensitive Y/N)"
if ($proceed -eq "Y") {


$errors = @()
$updated = 0

foreach ($u in $users) {
    try {
        Update-MgUser -UserId $u.Id -AgeGroup 'minor' -ConsentProvidedForMinor 'granted' -ErrorAction Stop
        $updated++
    }
    catch {
        $errors += [pscustomobject]@{
            UserPrincipalName = $u.UserPrincipalName
            Id                = $u.Id
            Error             = $_.Exception.Message
        }
    }
}

Write-Host "`nUpdated $updated user(s)." -ForegroundColor Green
if ($errors.Count -gt 0) {
    $errPath = ".\users-update-errors-$($Prefix)-$stamp.csv"
    $errors | Export-Csv -Path $errPath -NoTypeInformation -Encoding UTF8
    Write-Host "Logged $($errors.Count) error(s) to $errPath" -ForegroundColor Yellow
}


} else {
    Write-Host "⚠️ No changes made."
}

# -----------------------------
# 5) Post-check (optional)
# -----------------------------
# Re-check a sample after update
(Get-MgUser -Top 5 -Filter $filter -Property "id,displayName,userPrincipalName,ageGroup,consentProvidedForMinor") |
    Select-Object DisplayName, UserPrincipalName, AgeGroup, ConsentProvidedForMinor |
    Format-Table -AutoSize
