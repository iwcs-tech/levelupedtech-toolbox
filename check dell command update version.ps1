
# Define registry path and value
$regPath = "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings"
$valueName = "ProductVersion"
$requiredVersion = [Version]"5.4.0"

# Check if the registry key exists
if (Test-Path $regPath) {
    $productVersionString = Get-ItemProperty -Path $regPath -Name $valueName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $valueName

    if ($productVersionString) {
        try {
            $productVersion = [Version]$productVersionString
            if ($productVersion -ge $requiredVersion) {
                Write-Output "Compliant: ProductVersion ($productVersion) is greater than or equal to $requiredVersion."
            } else {
                Write-Output "Non-compliant: ProductVersion ($productVersion) is less than $requiredVersion."
            }
        } catch {
            Write-Output "Error: ProductVersion value is not a valid version format."
        }
    } else {
        Write-Output "Error: ProductVersion value not found."
    }
} else {
    Write-Output "Error: Registry path not found."
}
