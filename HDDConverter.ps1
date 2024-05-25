# Ask user for drive letters to be excluded
$excludedDrivesInput = Read-Host "Enter additional drive letters to be excluded from this action, separated by commas. C: is excluded by default (e.g., C,D,E)"
$excludedDrives = if ($excludedDrivesInput -ne '') { $excludedDrivesInput.Split(',') | ForEach-Object { $_.Trim().ToUpper() } } else { @() }
# Always exclude C: drive by default
$excludedDrives += "C"

# Ask user for drive letters to convert
$driveLetters = Read-Host "Enter the drive letters of the disks to convert, separated by commas (e.g., F,G,H)"
if (-not $driveLetters) {
    Write-Host "No drive letters were entered. Exiting script."
    exit
}
$drives = $driveLetters.Split(',')

# Get the directory path of the current script
$scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Convert each drive from GPT to MBR and format to FAT32
foreach ($drive in $drives) {
    $drive = $drive.Trim().ToUpper()  # Convert to uppercase to standardize input

    if ($excludedDrives -contains $drive) {
        Write-Host "Skipping drive $drive as it is excluded."
        continue
    }

    # Attempt to get the disk number using the drive letter
    $disk = Get-Partition -DriveLetter $drive | Get-Disk

    if ($disk -eq $null) {
        Write-Host "No disk found for drive $drive. Skipping..."
        continue
    }

    $diskNumber = $disk.Number
    $diskpartScript = @"
select disk $diskNumber
clean
convert mbr
create partition primary
select partition 1
active
format fs=fat32 quick
assign letter=$drive
"@

    $diskpartScriptPath = "$env:TEMP\diskpart_script.txt"
    $diskpartScript | Set-Content $diskpartScriptPath

    try {
        Start-Process "diskpart" -ArgumentList "/s $diskpartScriptPath" -NoNewWindow -Wait -ErrorAction Stop
        Write-Host "DiskPart operations completed successfully."

        # Verify the partition style
        $disk = Get-Partition -DriveLetter $drive | Get-Disk
        $partitionStyle = $disk.PartitionStyle
        Write-Host "Verification: The partition style of drive $drive is now: $partitionStyle" -ForegroundColor Green

        # Combine the script directory path with the executable name
        $fat32FormatExePath = Join-Path -Path $scriptPath -ChildPath "fat32format.exe"

        # Format the drive to FAT32 with the appropriate cluster size
        Start-Process -FilePath $fat32FormatExePath -ArgumentList "-c64 $drive`:" -NoNewWindow -Wait
        Write-Host "Drive $drive has been formatted to FAT32."

        # Check and report the partition size
        $volumeInfo = Get-Volume -DriveLetter $drive
        Write-Host "Partition size of drive $drive : $($volumeInfo.Size / 1TB) TB" -ForegroundColor Cyan

    }
    catch {
        Write-Host "Error processing commands: $_"
    }

    Remove-Item $diskpartScriptPath -Force
}

Write-Host "All specified drives have been processed."