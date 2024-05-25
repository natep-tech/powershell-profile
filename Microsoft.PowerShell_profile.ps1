### PowerShell Profile Refactor
### Version 1.04 - Refactored

# Initial GitHub.com connectivity check with 1 second timeout
$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

# Path to folder that contains the powershell profile
$PROFILEFOLDER = $PROFILE | Split-Path

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# Check for Profile Updates
function Update-Profile {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping profile update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        $url = "https://raw.githubusercontent.com/ChrisTitusTech/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
        $oldhash = Get-FileHash $PROFILE
        Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
        $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
        if ($newhash.Hash -ne $oldhash.Hash) {
            Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
            Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        }
    } catch {
        Write-Error "Unable to check for `$profile updates"
    } finally {
        Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
    }
}
Update-Profile

function Update-PowerShell {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to GitHub.com not responding within 1 second." -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell


# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function Get-UnixPrompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
Set-Alias -Name prompt -Value Get-UnixPrompt
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

function Edit-CurrentUserAllHostsProfile {
    vim $PROFILE.CurrentUserAllHosts
}

function Set-File($file) { "" | Out-File $file -Encoding ASCII }
Set-Alias -Name touch -Value Set-File

function Find-FilePath($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.directory)\$($_)"
    }
}
Set-Alias -Name ff -Value Find-FilePath

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# System Utilities
function Get-SystemUptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}
Set-Alias -Name uptime -Value Get-SystemUptime

function Restart-Profile {
    & $profile
}
Set-Alias -Name reload-profile -Value Restart-Profile

function Expand-ZipFile ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
Set-Alias -Name unzip -Value Expand-ZipFile

function Deploy-HasteBin {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }
    
    $FilePath = $args[0]
    
    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }
    
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Write-Output $url
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}
Set-Alias -Name hb -Value Deploy-HasteBin

function Find-FilePattern($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}
Set-Alias -Name grep -Value Find-FilePattern

Set-Alias -Name df -Value Get-Volume

function Edit-TextStream($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}
Set-Alias -Name sed -Value Edit-TextStream

function Find-Executable($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}
Set-Alias -Name which -Value Find-Executable

function Export-Variable($name, $value) {
    set-item -force -path "env:$name" -value $value;
}
Set-Alias -Name export -Value Export-Variable

function Stop-SelectedProcess($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}
Set-Alias -Name pkill -Value Stop-SelectedProcess

function Find-ProcessID($name) {
    Get-Process $name
}
Set-Alias -Name pgrep -Value Find-ProcessID

function Get-nFirstFileLines {
  param($Path, $n = 10)
  Get-Content $Path -Head $n
}
Set-Alias -Name head -Value Get-nFileLines

function Get-nLastFileLines {
  param($Path, $n = 10)
  Get-Content $Path -Tail $n
}
Set-Alias -Name tail -Value Get-nLastFileLines

# Quick File Creation
function New-File { param($name) New-Item -ItemType "file" -Path . -Name $name }
Set-Alias -Name nf -Value New-File

# Directory Management
function New-ChangeDirectory { param($dir) mkdir $dir -Force; Set-Location $dir }
Set-Alias -Name mkcd -Value New-ChangeDirectory

### Quality of Life Aliases

# Navigation Shortcuts
function Set-UserDocumentsLocation { Set-Location -Path $HOME\Documents }
Set-Alias -Name docs -Value Set-UserDocumentsLocation

function Set-UserDesktopLocation { Set-Location -Path $HOME\Desktop }
Set-Alias -Name dtop -Value Set-UserDesktopLocation

# Quick Access to Editing the Profile
function Edit-Profile { vim $PROFILE }
Set-Alias -Name ep -Value Edit-Profile

# Simplified Process Management
function Stop-MultipleProcesses { Stop-Process -Name $args[0] }
Set-Alias -Name k9 -Value Stop-MultipleProcesses

# Enhanced Listing
function Get-AllChildItems { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
Set-Alias -Name la -Value Get-AllChildItems

function Get-HiddenChildItems { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }
Set-Alias -Name ll -Value Get-HiddenChildItems

# Git Shortcuts
function Get-GitStatus { git status }
Set-Alias -Name gs -Value Get-GitStatus

function Add-AllGitChanges { git add . }
Set-Alias -Name ga -Value Add-AllGitChanges

function Submit-GitCommit { param($m) git commit -m "$m" }
Set-Alias -Name gc -Value Submit-GitCommit

function Publish-GitChanges { git push }
Set-Alias -Name gp -Value Publish-GitChanges

function Show-GitHubDirectory { z Github }
Set-Alias -Name g -Value Show-GitHubDirectory

function Submit-AllGitChanges {
    git add .
    git commit -m "$args"
}
Set-Alias -Name gcom -Value Submit-AllGitChanges

function Publish-AllGitChanges {
    git add .
    git commit -m "$args"
    git push
}
Set-Alias -Name lazyg -Value Publish-AllGitChanges

# Quick Access to System Information
Set-Alias -Name sysinfo -Value Get-ComputerInfo

# Networking Utilities
Set-Alias -Name flushdns -Value Clear-DnsClientCache

# Clipboard Utilities
function Set-ClipboardToArgs { Set-Clipboard $args[0] }
Set-Alias -Name cpy -Value Set-ClipboardToArgs

Set-Alias -Name pst -Value Get-Clipboard

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

## Final Line to set prompt
oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json | Invoke-Expression
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

# PowerToys CommandNotFound module
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58
