# install chocolatey package manager
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
# install core apps
choco install azure-cli -y
choco install kubernetes-cli -y
choco install azure-kubelogin -y
# install other helpful apps
choco install lens -y
choco install vscode -y
choco install google-chrome-x64 -y
choco install 7zip -y 
choco install notepadplusplus -y
choco install filezilla -y
choco install git -y
choco install git-credential-manager-for-windows -y

