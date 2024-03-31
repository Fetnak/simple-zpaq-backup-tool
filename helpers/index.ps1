function Write-InternalError ([string] $message) {
    Write-Host "`e[31m!`e[0m $message"
}

function Write-InternalSuccess ([string] $message) {
    Write-Host "`e[32m!`e[0m $message"
}

function Write-InternalWarning ([string] $message) {
    Write-Host "`e[33m!`e[0m $message"
}

function Write-InternalInfo ([string] $message) {
    Write-Host "`e[36m!`e[0m $message"
}

function Write-InternalList ([string] $message) {
    Write-Host "  `e[33m-`e[0m $message"
}

function Write-InternalOption ([string] $name, [string] $value) {
    Write-Host "`e[36m!`e[0m $($name) = `e[33m$($value)`e[0m"
}

function Write-InternalLog([string] $message) {
    Write-Host "[`e[33m$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`e[0m] $message"
}

function Invoke-LoadModule ([string] $module) {
    # If module is imported say that and do nothing
    if (Get-Module | Where-Object { $_.Name -eq $module }) {
        return $true
    }

    # If module is not imported, but available on disk then import
    if (Get-Module -ListAvailable | Where-Object { $_.Name -eq $module }) {
        Import-Module $module
        return $true
    }

    # If module is not imported, not available on disk, but is in online gallery then install and import
    if (Find-Module -Name $module | Where-Object { $_.Name -eq $module }) {
        Install-Module -Name $module -Force -Scope CurrentUser
        Import-Module $module
        return $true
    }

    Write-InternalError "Module $module is not imported, not available and not in the online gallery!"

    return $false
}

function Convert-StringToTime([string] $time) {
    [int]$days = 0
    [int]$hours = 0
    [int]$minutes = 0
    [int]$seconds = 0

    if ($time -match '^\d+$') {
        return [int]$time
    }

    if ($time -match '(\d+)d') {
        $days = [int]$matches[1]
    }

    if ($time -match '(\d+)h') {
        $hours = [int]$matches[1]
    }
    
    if ($time -match '(\d+)m') {
        $minutes = [int]$matches[1]
    }

    if ($time -match '(\d+)s') {
        $seconds = [int]$matches[1]
    }

    return [int](($days * 24 * 60 * 60 * 1000) + ($hours * 60 * 60 * 1000) + ($minutes * 60 * 1000) + ($seconds * 1000))
}

function Convert-TimeToString([int]$milliseconds) {
    [int]$totalSeconds = [math]::Floor($milliseconds / 1000)
    [int]$seconds = $totalSeconds % 60
    [int]$totalMinutes = [math]::Floor($totalSeconds / 60)
    [int]$minutes = $totalMinutes % 60
    [int]$totalHours = [math]::Floor($totalMinutes / 60)
    [int]$hours = $totalHours % 24
    [int]$days = [math]::Floor($totalHours / 24)
    $milliseconds %= 1000

    [string[]]$result = @()

    if ($days -gt 0) {
        $null = $result += "$days Days"
    }
    
    if ($hours -gt 0) {
        $null = $result += "$hours Hours"
    }
    
    if ($minutes -gt 0) {
        $null = $result += "$minutes Minutes"
    }

    if (($seconds -gt 0) -or ($result.Count -eq 0)) {
        $null = $result += "$seconds Seconds"
    }

    if ($milliseconds -gt 0) {
        $null = $result += "$milliseconds Milliseconds"
    }

    return [string]($result -join ' ')
}

function Invoke-ParseConfig ([string] $configDir) {
    # Check if path exists
    if (!(Test-Path $configDir -PathType Leaf)) {
        Write-InternalError "Config file does not exist!"
        EXIT 1
    }

    # Load the YAML module
    if (!(Invoke-LoadModule "powershell-yaml")) {
        EXIT 1
    }

    # Get the config
    $yaml = Get-Content $configDir | ConvertFrom-Yaml
 
    # Check for the base config entry
    if (!$yaml.ContainsKey('config')) {
        Write-InternalError "Config does not have 'config' entry"
    }

    $config = $yaml['config']

    # This field is required
    if (!$config.containsKey('target')) {
        Write-InternalError "Config does not have a 'target' entry"
        EXIT 1
    }
    
    [string]$targetPath = $config['target']

    # Default values are set in the else clause
    [string]$name = if ($config.containsKey('name')) { $config['name'] } else { 'backup' }
    [string]$savePath = if ($config.containsKey('save_path')) { $config['save_path'] } else { 'backup.zpaq' }
    [string]$periodString = if ($config.containsKey('period')) { $config['period'] } else { '30m' }
    [string[]]$ignoreList = if ($config.containsKey('ignore')) { [string[]]$config['ignore'] } else { [string[]]@() }

    [int]$period = Convert-StringToTime $periodString
    $savePath = [IO.Path]::GetFullPath($savePath, $PWD)
    $targetPath = [IO.Path]::GetFullPath($targetPath, $PWD)
    [string[]]$ignoreListRelative = $ignoreList.Clone()

    for ($index = 0; $index -lt $ignoreList.Count; $index++) {
        $ignoreList[$index] = Join-Path $targetPath $ignoreList[$index]
    }

    # Display the config
    Write-InternalOption "Save Path  " $savePath
    Write-InternalOption "Target Path" $targetPath
    Write-InternalOption "Period     " $(Convert-TimeToString $period)
    Write-InternalInfo   "IgnoreList "
    
    foreach ($ignoreEntry in $ignoreList) {
        Write-InternalList $ignoreEntry
    }

    Write-Host ""

    return [PSCustomObject]@{
        savePath           = $savePath
        targetPath         = $targetPath
        name               = $name
        period             = $period
        ignoreList         = $ignoreList
        ignoreListRelative = $ignoreListRelative
    }
}
