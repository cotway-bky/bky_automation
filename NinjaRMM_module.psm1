# NinjaRMM_module.psm1

function Install-NinjaRmm {
    # Check if the temp directory exists, if not create it
    if (-not (Test-Path -Path c:\temp)) {
        New-Item -Path c:\temp -ItemType Directory | Out-Null
    }

    # Define the URI and output path for the installer
    $uri = "https://ca.ninjarmm.com/agent/installer/30aff85f-d023-4a16-96cd-8be0975ac0af/ua488edmonton-6.0.1901-windows-installer.msi"
    $outputPath = "c:\temp\NinjaAgent.msi"

    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
}
    # Download the installer
    Invoke-WebRequest -Uri $uri -OutFile $outputPath -Headers $headers

    # Install the MSI file
    Start-Process -FilePath msiexec -ArgumentList "/i $outputPath /qn" -Wait
}

$ninjaInstalled = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "NinjaRMMAgent" }

if ($ninjaInstalled) {
    Write-Host "NinjaRMMAgent is installed." -ForegroundColor Green
} else {
    Write-Host "NinjaRMMAgent failed to install." -ForegroundColor Red
}


# Export the function for use
#Export-ModuleMember -Function Install-NinjaRmm
