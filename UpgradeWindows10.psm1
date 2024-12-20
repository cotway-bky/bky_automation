function Upgrade-Windows10 {
    param (
        [string]$OutputPath = "C:\temp",
        [string]$Windows11InstallerUrl = "https://go.microsoft.com/fwlink/?linkid=2171764"
    )

    # Ensure Output Directory Exists
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory | Out-Null
    }

    # Initialize Variables
    $exitCode = 0
    $outObject = @{ returnCode = -2; returnResult = "FAILED TO RUN"; returnReason = ""; logging = "" }
    
    [int]$MinOSDiskSizeGB = 64
    [int]$MinMemoryGB = 4
    [Uint32]$MinClockSpeedMHz = 1000
    [Uint32]$MinLogicalCores = 2
    [Uint16]$RequiredAddressWidth = 64

    $CapableFile = Join-Path $OutputPath "Capable.txt"
    $NotCapableFile = Join-Path $OutputPath "NotCapable.txt"

    # Remove prior instances of files
    if (Test-Path -Path $CapableFile) { Remove-Item -Path $CapableFile -Recurse }
    if (Test-Path -Path $NotCapableFile) { Remove-Item -Path $NotCapableFile -Recurse }

    # Check Storage
    try {
        $osDrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive
        $osDriveSize = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$osDrive'" | Select-Object -ExpandProperty Size
        $osDriveSizeGB = [math]::Floor($osDriveSize / 1GB)

        if ($osDriveSizeGB -lt $MinOSDiskSizeGB) {
            $outObject.returnCode = 1
            $outObject.returnReason += "Insufficient disk space. "
            $outObject.logging += "Storage check failed: $osDriveSizeGB GB available, $MinOSDiskSizeGB GB required. "
        }
    } catch {
        $outObject.returnCode = -1
        $outObject.logging += "Storage check error: $_.Exception.Message. "
    }

    # Check Memory
    try {
        $memory = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | Select-Object -ExpandProperty Sum
        $memoryGB = [math]::Floor($memory / 1GB)

        if ($memoryGB -lt $MinMemoryGB) {
            $outObject.returnCode = 1
            $outObject.returnReason += "Insufficient memory. "
            $outObject.logging += "Memory check failed: $memoryGB GB available, $MinMemoryGB GB required. "
        }
    } catch {
        $outObject.returnCode = -1
        $outObject.logging += "Memory check error: $_.Exception.Message. "
    }

    # Check Processor
    try {
        $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        if ($cpu.AddressWidth -ne $RequiredAddressWidth -or $cpu.MaxClockSpeed -lt $MinClockSpeedMHz -or $cpu.NumberOfLogicalProcessors -lt $MinLogicalCores) {
            $outObject.returnCode = 1
            $outObject.returnReason += "Processor does not meet requirements. "
            $outObject.logging += "Processor check failed: AddressWidth=$($cpu.AddressWidth), MaxClockSpeed=$($cpu.MaxClockSpeed), LogicalCores=$($cpu.NumberOfLogicalProcessors). "
        }
    } catch {
        $outObject.returnCode = -1
        $outObject.logging += "Processor check error: $_.Exception.Message. "
    }

    # Check TPM
    try {
        $tpm = Get-Tpm
        if (-not $tpm.TpmPresent -or $tpm.SpecVersion -lt 2.0) {
            $outObject.returnCode = 1
            $outObject.returnReason += "TPM version not sufficient. "
            $outObject.logging += "TPM check failed: Version=$($tpm.SpecVersion). "
        }
    } catch {
        $outObject.returnCode = -1
        $outObject.logging += "TPM check error: $_.Exception.Message. "
    }

    # Check Secure Boot
    try {
        if (-not (Confirm-SecureBootUEFI)) {
            $outObject.returnCode = 1
            $outObject.returnReason += "Secure Boot not enabled. "
            $outObject.logging += "Secure Boot check failed. "
        }
    } catch {
        $outObject.returnCode = -1
        $outObject.logging += "Secure Boot check error: $_.Exception.Message. "
    }

    # Generate Results
    switch ($outObject.returnCode) {
        0 {
            $outObject.returnResult = "CAPABLE"
            "Computer Name: $env:Computername`n" | Out-File -FilePath $CapableFile
            "Time: $(Get-Date)`n" | Out-File -FilePath $CapableFile -Append
            $outObject | Format-List | Out-File -FilePath $CapableFile -Append

            # Download and execute installer
            $WebClient = New-Object System.Net.WebClient
            $installerPath = Join-Path $OutputPath "Windows11.exe"
            $WebClient.DownloadFile($Windows11InstallerUrl, $installerPath)
            Start-Process -FilePath $installerPath -ArgumentList '/SkipEULA /Auto Upgrade /NoRestartUI' -Wait
        }
        1 {
            $outObject.returnResult = "NOT CAPABLE"
            "Computer Name: $env:Computername`n" | Out-File -FilePath $NotCapableFile
            "Time: $(Get-Date)`n" | Out-File -FilePath $NotCapableFile -Append
            $outObject | Format-List | Out-File -FilePath $NotCapableFile -Append
            Write-Host "Asset not eligible for Windows 11 upgrade. Check $NotCapableFile"
        }
        default {
            Write-Host "An error occurred during the check. Logs saved to $OutputPath"
        }
    }
}
