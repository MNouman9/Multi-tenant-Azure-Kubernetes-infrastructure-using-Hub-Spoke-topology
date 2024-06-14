param (
    [string]$devOpsUrl,
    [string]$personalAccessToken,
    [string]$agentPoolName
)

Write-Host "[INFO] Core Software Installation Starting..."
# install chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# install core apps
choco install azure-cli -y
choco install kubernetes-cli -y
choco install azure-kubelogin -y
choco install git -y
Write-Host "[INFO] Core Software Installation Complete!"

# PowerShell script for setting up an Azure DevOps self-hosted agent
Write-Host "[INFO] Azure DevOps Agent Setup Starting..."
# --- Configuration Variables ---
$agentDownloadUrl = "https://vstsagentpackage.azureedge.net/agent/3.230.2/vsts-agent-win-x64-3.230.2.zip" # Update this with the actual download URL for the agent
$agentZipPath = "C:\tempAzureBuildAgent" # Update this with the path to your downloaded agent zip file
$agentInstallPath = "C:\agent" # Desired installation path for the agent
$agentName = "WindowsBuildAgent" # The name for your agent

# --- Download Azure DevOps Agent ---

# Download the agent
Invoke-WebRequest -Uri $agentDownloadUrl -OutFile $agentZipPath

# Create installation directory
New-Item -ItemType Directory -Force -Path $agentInstallPath

# Extract the agent zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($agentZipPath, $agentInstallPath)

# Change directory to the agent install path
Set-Location $agentInstallPath

# Configure the agent
.\config.cmd --unattended --agent $agentName --pool $agentPoolName --url $devOpsUrl --auth 'PAT' --token $personalAccessToken --runAsService --replace --acceptTeeEula

# Optional: Remove the agent zip file after installation (if desired)
Remove-Item -Path $agentZipPath

# Script end
Write-Host "[INFO] Azure DevOps Agent Setup Complete!"

# Initialize the disk
#Get-Disk | Where-Object IsOffline -Eq $True | Initialize-Disk -PartitionStyle GPT
# Create a new partition
#New-Partition -DiskNumber 1 -UseMaximumSize
# Format the partition
#Format-Volume -DriveLetter E -FileSystem NTFS -NewFileSystemLabel "DataDisk" -AllocationUnitSize 64KB


# Install/Enable Docker
Write-Host "[INFO] Docker Setup Starting..."
New-Item -Path 'C:\Program Files\Docker' -ItemType Directory
New-Item -Path 'D:\DockerData' -ItemType Directory

Set-Location C:\
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1
# Read the content of the script file into a variable
$scriptPath = "C:\install-docker-ce.ps1"
$scriptContent = Get-Content -Path $scriptPath -Raw

# Define your new code block
$newCodeBlock = @"
Move-Item -Path 'C:\Windows\System32\docker.exe' -Destination 'C:\Program Files\Docker\docker.exe'
Move-Item -Path 'C:\Windows\System32\dockerd.exe' -Destination 'C:\Program Files\Docker\dockerd.exe'

# Specify the path you want to add
`$newPath = "C:\Program Files\Docker\"

# Get the current system environment variables
`$existingPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

# Check if the path already exists in the system environment variables
if (`$existingPath -notcontains `$newPath) {
    # Append the new path to the existing paths, separated by a semicolon
    `$newSystemPath = "`$existingPath;`$newPath"

    # Set the updated path as a system environment variable
    [System.Environment]::SetEnvironmentVariable("Path", `$newSystemPath, [System.EnvironmentVariableTarget]::Machine)

    Write-Host "Path added to system environment variables. Changes will take effect in new sessions."
} else {
    Write-Host "Path already exists in system environment variables. No changes made."
}

sc.exe stop docker

`$config = @{
    "hosts" = @("tcp://0.0.0.0:2376", "npipe:////./pipe/docker_engine")
    "data-root" = "D:\DockerData"
}
`$config | ConvertTo-Json | Set-Content -Path 'C:\ProgramData\Docker\config\daemon.json'
sc.exe config docker binpath= "C:\Program Files\Docker\dockerd.exe --run-service -D"

sc.exe start docker

Write-Host "Docker Setup Complete!"
"@

# Replace the line containing "Script complete!" with the new code block
$modifiedScript = $scriptContent -replace 'Write-Output "Script complete!"', $newCodeBlock

# Write the modified content back to the script file
$modifiedScript | Set-Content -Path $scriptPath

.\install-docker-ce.ps1