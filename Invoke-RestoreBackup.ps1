param (
    [Parameter(Position = 0)][string]$configDir = "./backup-config.yaml"
)

. ./helpers/index.ps1

$config = Invoke-ParseConfig $configDir

# Display available options
Invoke-Expression "zpaq l `"$($config.savePath)`""
| Where-Object { $_ -match '^([^/]*/){1}$' }
| ForEach-Object { $_ -replace "^.*($($config.name)-\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}).*", "  `e[33m-`e[0m `$1" }

# Get the desired backup name
$backupName = Read-Host "Enter the backup name, for example `"$($config.name)-$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss")`""

# Remove everything except ingoreList in the target path
$ignoreList = $config.ignoreListRelative | ForEach-Object { $_.TrimEnd('/').TrimEnd('\') }
Get-ChildItem -Path $config.targetPath -Exclude $ignoreList | Remove-Item -Recurse

# Restore the backup
Invoke-Expression "zpaq x `"$($config.savePath)`" `"$($backupName)`" -to `"$($config.targetPath)`"" 2>&1 | Out-Null

Write-InternalSuccess "Backup restored successfully"

