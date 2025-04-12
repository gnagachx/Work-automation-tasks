# Script to run Disk Cleanup utility on multiple remote Windows servers

# Prompt user for server list file path
$serverListFile = Read-Host "Please enter the path to the server list file (.txt or .csv) (e.g., C:\Scripts\servers.txt)"

# Verify the file exists
if (-not (Test-Path $serverListFile)) {
    Write-Error "The file path '$serverListFile' does not exist. Please check the path and try again."
    exit 1
}

# Determine file type and read servers
if ($serverListFile -like "*.txt") {
    # Read from text file (one server per line)
    $servers = Get-Content -Path $serverListFile -ErrorAction Stop
} elseif ($serverListFile -like "*.csv") {
    # Read from CSV file (assuming a column named "Server")
    $servers = Import-Csv -Path $serverListFile -ErrorAction Stop | Select-Object -ExpandProperty Server
} else {
    Write-Error "Unsupported file format. Please use .txt or .csv."
    exit 1
}

# Prompt for credentials interactively
Write-Host "Please enter credentials for remote access (e.g., DOMAIN\Username):" -ForegroundColor Yellow
$cred = Get-Credential

# Prompt for drive letter(s) interactively
$driveInput = Read-Host "Enter the drive letter(s) to clean (e.g., C:, D:, E:), separated by commas"
$drives = $driveInput.Split(',') | ForEach-Object { $_.Trim() + ":" } | Where-Object { $_ -match "^[A-Z]:$" }

if ($drives.Count -eq 0) {
    Write-Error "No valid drive letters provided. Exiting."
    exit 1
}

# Log file path
$logFile = "C:\Scripts\DiskCleanupLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Function to write to log file
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
}

# Test and establish remote sessions
foreach ($server in $servers) {
    try {
        Write-Log "Attempting to connect to $server..."

        # Test connection
        if (Test-Connection -ComputerName $server -Count 1 -ErrorAction Stop) {
            Write-Log "Successfully pinged $server. Establishing remote session..."

            # Create remote session with credentials
            $session = New-PSSession -ComputerName $server -Credential $cred -ErrorAction Stop

            foreach ($drive in $drives) {
                Write-Log "Starting Disk Cleanup on $server for drive $drive..."

                # Invoke command to run Disk Cleanup
                Invoke-Command -Session $session -ScriptBlock {
                    param ($driveLetter)
                    # Start Disk Cleanup with system files option
                    $cleanmgrArgs = @("/sagerun:1", "/d", $driveLetter)
                    Start-Process -FilePath "cleanmgr.exe" -ArgumentList $cleanmgrArgs -Wait -NoNewWindow
                } -ArgumentList $drive

                Write-Log "Completed Disk Cleanup on $server for drive $drive."
            }

            # Close the session
            Remove-PSSession -Session $session
            Write-Log "Closed remote session for $server."
        }
    }
    catch {
        Write-Log "Error processing $server`: $_"
        continue
    }
}

Write-Log "Script execution completed. Check the log file at $logFile for details."
Write-Host "Script execution completed. Check the log file at $logFile for details."