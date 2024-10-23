# NinjaRMM_module.psm1

function Install-NinjaRmm {
    # Check if the temp directory exists, if not create it
    if (-not (Test-Path -Path c:\temp)) {
        New-Item -Path c:\temp -ItemType Directory | Out-Null
    }

    # Define the URI and output path for the installer
    $uri = "https://ca.ninjarmm.com/agent/installer/30aff85f-d023-4a16-96cd-8be0975ac0af/ua488edmonton-6.0.1901-windows-installer.msi"
    $outputPath = "c:\temp\NinjaAgent.msi"

    # Download the installer
    Invoke-WebRequest -Uri $uri -OutFile $outputPath -Headers $headers

    # Install the MSI file
    Start-Process -FilePath msiexec -ArgumentList "/i $outputPath /qn" -Wait
}

# Export the function for use
#Export-ModuleMember -Function Install-NinjaRmm
