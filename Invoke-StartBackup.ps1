param (
    [Parameter(Position = 0)][string]$configDir = "./backup-config.yaml"
)

. ./helpers/index.ps1

$config = Invoke-ParseConfig $configDir

while ($true) {
    $arguments = @()
    
    # Collecting the arguments
    $arguments += "-m1"
    $arguments += "a"
    $arguments += "`"$($config.savePath)`""
    $arguments += "`"$($config.targetPath)`""
    $arguments += "-to"
    $backupName = "`"$($config.name)-$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss")`"/"
    $arguments += $backupName

    foreach ($ignoreEntry in $config.ignoreList) {
        $arguments += "-not"
        $arguments += "`"$ignoreEntry`""
    }
    
    # Creating the backup
    Write-InternalLog "Creating backup $($backupName)"
    Invoke-Expression "zpaq $($arguments -join ' ')" 2>&1 | Out-Null
    Write-InternalLog "Backup $($backupName) created"

    # Waiting between backup creation
    Start-Sleep -Milliseconds $config.period
}

