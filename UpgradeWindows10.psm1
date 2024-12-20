# Windows 11 Upgrade Check Script
# This script checks system compatibility for a Windows 11 upgrade and optionally initiates the upgrade process.

function Invoke-Windows11Upgrade {
    param (
        [string]$OutputFolder = "C:\temp",
        [string]$UpgradeToolURL = "https://go.microsoft.com/fwlink/?linkid=2171764"
    )

    # Ensure output folder exists
    if (-not (Test-Path -Path $OutputFolder)) {
        New-Item -Path $OutputFolder -ItemType Directory | Out-Null
    }

    # Set output file paths
    $CapableFile = Join-Path -Path $OutputFolder -ChildPath "Capable.txt"
    $NotCapableFile = Join-Path -Path $OutputFolder -ChildPath "NotCapable.txt"

    # Remove previous files
    Remove-Item -Path $CapableFile, $NotCapableFile -ErrorAction SilentlyContinue

    # Compatibility check logic
    $MinOSDiskSizeGB = 64
    $MinMemoryGB = 4
    $MinClockSpeedMHz = 1000
    $MinLogicalCores = 2
    $RequiredAddressWidth = 64

    $outObject = @{ returnCode = -2; returnResult = "FAILED TO RUN"; returnReason = ""; logging = "" }

    function Update-ReturnCode {
        param ([int]$ReturnCode)
        switch ($ReturnCode) {
            0 { if ($outObject.returnCode -eq -2) { $outObject.returnCode = $ReturnCode } }
            1 { $outObject.returnCode = $ReturnCode }
            -1 { if ($outObject.returnCode -ne 1) { $outObject.returnCode = $ReturnCode } }
        }
    }

    try {
        # Storage Check
        $osDrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive
        $osDriveSize = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$osDrive'" | Select-Object -ExpandProperty Size
        if ($osDriveSize / 1GB -lt $MinOSDiskSizeGB) {
            Update-ReturnCode -ReturnCode 1
            $outObject.logging += "Storage check failed. OS drive size: $($osDriveSize / 1GB)GB\n"
        }

        # Memory Check
        $memory = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | Select-Object -ExpandProperty Sum
        if ($memory / 1GB -lt $MinMemoryGB) {
            Update-ReturnCode -ReturnCode 1
            $outObject.logging += "Memory check failed. Available memory: $($memory / 1GB)GB\n"
        }

        # CPU Check
        $cpu = Get-WmiObject -Class Win32_Processor
        if ($cpu.NumberOfLogicalProcessors -lt $MinLogicalCores -or $cpu.MaxClockSpeed -lt $MinClockSpeedMHz -or $cpu.AddressWidth -ne $RequiredAddressWidth) {
            Update-ReturnCode -ReturnCode 1
            $outObject.logging += "CPU check failed.\n"
        }

        # TPM Check
        $tpm = Get-Tpm
        if (-not $tpm.TpmPresent -or $tpm.SpecVersion -lt 2) {
            Update-ReturnCode -ReturnCode 1
            $outObject.logging += "TPM check failed.\n"
        }

        # Secure Boot Check
        try {
            if (-not (Confirm-SecureBootUEFI)) {
                Update-ReturnCode -ReturnCode 1
                $outObject.logging += "Secure Boot check failed.\n"
            }
        } catch {
            Update-ReturnCode -ReturnCode -1
            $outObject.logging += "Secure Boot check exception: $_\n"
        }

        if ($outObject.returnCode -eq 0) {
            $outObject.returnResult = "CAPABLE"
            "Computer Name: $env:ComputerName`nTime: $(Get-Date)\n" | Out-File -FilePath $CapableFile
            $outObject | Out-File -FilePath $CapableFile -Append
        } else {
            $outObject.returnResult = "NOT CAPABLE"
            "Computer Name: $env:ComputerName`nTime: $(Get-Date)\n" | Out-File -FilePath $NotCapableFile
            $outObject | Out-File -FilePath $NotCapableFile -Append
        }

        if (Test-Path -Path $CapableFile) {
            # Download and run upgrade tool
            $UpgradeToolPath = Join-Path -Path $OutputFolder -ChildPath "Windows11.exe"
            Invoke-WebRequest -Uri $UpgradeToolURL -OutFile $UpgradeToolPath
            Start-Process -FilePath $UpgradeToolPath -ArgumentList '/SkipEULA /Auto Upgrade /NoRestartUI' -Wait
        } else {
            Write-Host "Asset not eligible for Windows 11 upgrade. Check $NotCapableFile"
        }

    } catch {
        Update-ReturnCode -ReturnCode -1
        $outObject.logging += "Error: $_\n"
    }

    return $outObject
}

# Entry point
Invoke-Windows11Upgrade
