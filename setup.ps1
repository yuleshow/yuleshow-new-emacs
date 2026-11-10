$ErrorActionPreference = 'Stop'

$repositoryArchive = 'https://github.com/yuleshow/yuleshow-new-emacs/archive/refs/heads/main.zip'
$scriptDir = (Resolve-Path -LiteralPath $PSScriptRoot).Path.TrimEnd('\')
$configDir = Join-Path $HOME '.emacs.d'
$backupRoot = Join-Path $HOME 'yuleshow-emacs-backup'

$localAppData = $env:LOCALAPPDATA
if (-not $localAppData) {
    $installDir = Join-Path $HOME 'AppData\Local\yuleshow-emacs'
}
else {
    $installDir = Join-Path $localAppData 'yuleshow-emacs'
}

$sourceDir = $null
if (Test-Path -LiteralPath (Join-Path $scriptDir 'init.el')) {
    $sourceDir = $scriptDir
}
elseif (Test-Path -LiteralPath (Join-Path $installDir 'init.el')) {
    $sourceDir = $installDir
}
else {
    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    try {
        $archivePath = Join-Path $tempDir 'repository.zip'
        $extractDir = Join-Path $tempDir 'extract'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $repositoryArchive -OutFile $archivePath -UseBasicParsing
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir
        $downloadedDir = Join-Path $extractDir 'yuleshow-new-emacs-main'
        if (-not (Test-Path -LiteralPath (Join-Path $downloadedDir 'init.el'))) {
            throw 'Downloaded archive does not contain init.el.'
        }

        New-Item -ItemType Directory -Path (Split-Path -Parent $installDir) -Force | Out-Null
        Move-Item -LiteralPath $downloadedDir -Destination $installDir
        $sourceDir = $installDir
    }
    finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force
    }
}

function Get-BackupPath([string]$Path) {
    $candidate = "$Path.bak"
    $suffix = 1
    while ((Test-Path -LiteralPath $candidate) -or
           (Get-Item -LiteralPath $candidate -Force -ErrorAction SilentlyContinue)) {
        $candidate = "$Path.bak.$suffix"
        $suffix++
    }
    return $candidate
}

$configItem = Get-Item -LiteralPath $configDir -Force -ErrorAction SilentlyContinue
$alreadyInstalled = $false
if ($null -ne $configItem) {
    if ($configItem.PSObject.Properties['Target']) {
        $linkTarget = $configItem.Target
        if ($linkTarget -is [array]) {
            $linkTarget = $linkTarget[0]
        }
        if ($linkTarget) {
            $alreadyInstalled = [IO.Path]::GetFullPath($linkTarget).TrimEnd('\') -ieq $sourceDir
        }
    }

    if (-not $alreadyInstalled -and (Test-Path -LiteralPath (Join-Path $configDir 'init.el'))) {
        $sourceHash = (Get-FileHash -LiteralPath (Join-Path $sourceDir 'init.el')).Hash
        $installedHash = (Get-FileHash -LiteralPath (Join-Path $configDir 'init.el')).Hash
        $alreadyInstalled = $sourceHash -eq $installedHash
    }
}

if ($alreadyInstalled) {
    Write-Output "$configDir already points to or matches $sourceDir"
}
else {
    if ($null -ne $configItem) {
        $backupDir = Get-BackupPath $configDir
        Move-Item -LiteralPath $configDir -Destination $backupDir
        Write-Output "Backed up existing $configDir to $backupDir"
    }

    New-Item -ItemType Junction -Path $configDir -Target $sourceDir | Out-Null
    Write-Output "Created junction: $configDir -> $sourceDir"
}

foreach ($directory in @('backups', 'auto-save', 'auto-save-list')) {
    New-Item -ItemType Directory -Path (Join-Path $backupRoot $directory) -Force | Out-Null
}
Write-Output "Ensured $backupRoot and its backup directories exist."
Write-Output 'Done! Start Emacs to use your new configuration.'
