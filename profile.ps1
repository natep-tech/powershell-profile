# Get details on installed modules and save to modules.json
function Get-ModuleInfo {
    # Get the path from the current PowerShell profile
    $path = $PROFILE | Split-Path

    # Get all installed modules
    $modules = Get-Module -ListAvailable | ForEach-Object {
        $moduleName = $_.Name
        [ordered]@{
            Name = $moduleName
            Version = $_.Version.ToString()
            Path = $_.Path
            RequiredModules = $_.RequiredModules | ForEach-Object { $_.Name }
            RepositorySourceLocation = $_.RepositorySourceLocation
        }
    }

    # Convert the list of modules to JSON and save it to a file
    $modules | ConvertTo-Json -Depth 5 | Set-Content -Path "$path/modules.json"
}
Get-ModuleInfo

function Find-ModuleUpdates {
    Write-Host "Checking for module updates..." -ForegroundColor Cyan

    # Get all installed modules
    $installedModules = Get-InstalledModule

    # Initialize an array to hold update information
    $updatesAvailable = @()

    # Check for updates for each installed module
    foreach ($module in $installedModules) {
        # Find the latest version available in the repository
        $latestModule = Find-Module -Name $module.Name

        # Compare versions
        if ([version]$module.Version -lt [version]$latestModule.Version) {
            # Create a custom object for the module with an update
            $updateInfo = [PSCustomObject]@{
                ModuleName      = $module.Name
                CurrentVersion  = $module.Version
                NewVersion      = $latestModule.Version
            }
            # Add the object to the updates array
            $updatesAvailable += $updateInfo
        }
    }

    # Output the updates in a table format, if any
    if ($updatesAvailable.Count -gt 0) {
        $updatesAvailable | Format-Table -Property ModuleName, CurrentVersion, NewVersion
        Write-Host "Run 'Update-InstalledModules' to update your modules. (If you only want to update certain ones, use the '-ConfirmEachUpdate' param)" -ForegroundColor Yellow
    } else {
        Write-Host "Your modules are all up to date." -ForegroundColor Green
    }
}
Find-ModuleUpdates

function Update-InstalledModules {
    param(
        [switch]$ConfirmEachUpdate
    )

    Write-Host "Checking for module updates..." -ForegroundColor Cyan

    # Get all installed modules
    $installedModules = Get-InstalledModule

    # Flag to check if any updates were made
    $updatesMade = $false

    # Check for updates for each installed module
    foreach ($module in $installedModules) {
        # Find the latest version available in the repository
        $latestModule = Find-Module -Name $module.Name

        # Compare versions
        if ([version]$module.Version -lt [version]$latestModule.Version) {
            if ($ConfirmEachUpdate) {
                # Ask for user confirmation before updating
                $updateConfirmation = Read-Host "Update available for $($module.Name) from $($module.Version) to $($latestModule.Version). Do you want to update? (Y/N)"
                if ($updateConfirmation -ne 'Y') {
                    continue
                }
            }
            Write-Host "Updating $($module.Name) from $($module.Version) to $($latestModule.Version)..." -ForegroundColor Yellow
            try {
                Update-Module -Name $module.Name
                Write-Host "Updated $($module.Name) successfully." -ForegroundColor Green
                $updatesMade = $true
            } catch {
                Write-Host "Failed to update $($module.Name): $_" -ForegroundColor Red
            }
        }
    }

    # Check if any updates were made
    if (-not $updatesMade) {
        Write-Host "Your modules are all up to date." -ForegroundColor Green
    }
}

# PowerToys CommandNotFound module
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58