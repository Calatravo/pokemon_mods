[CmdletBinding()]
param(
    [ValidateSet('Check','Install','Monitor')][string]$Mode = 'Check',
    [string]$GamePath,
    [ValidatePattern('^\d+-\d+$')][string]$Session,
    [int]$GamePid,
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [ValidateSet('es','en','fr')][string]$Language = 'es'
)
$ErrorActionPreference = 'Stop'

function Get-ModVersion([string]$Path) {
    $value = [IO.File]::ReadAllText($Path).Trim()
    if ($value -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid mod version' }
    return [version]$value
}

function Assert-NoLinkedParents([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and
            ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Linked installation paths are unsupported' }
        $cursor = Split-Path -Parent $cursor
    }
}

function Test-PackageDigest([string]$Path, $Asset) {
    if ((Get-Item -LiteralPath $Path).Length -ne $Asset.Size -or
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $Asset.Digest) { throw 'Download checksum mismatch' }
}

function Get-ReleaseAsset($Release) {
    if ($Release.draft -or $Release.prerelease -or $Release.tag_name -notmatch '^v(\d+\.\d+\.\d+)$') { throw 'Not a stable release' }
    $number = $Matches[1]
    $name = "Pokemon-Z-Mods-v$number.zip"
    $assets = @($Release.assets | Where-Object { $_.name -ceq $name })
    if ($assets.Count -ne 1) { throw 'Universal package missing' }
    $asset = $assets[0]
    $expected = "https://github.com/Calatravo/pokemon_mods/releases/download/v$number/$name"
    if ($asset.browser_download_url -cne $expected -or $asset.state -ne 'uploaded' -or
        $asset.digest -notmatch '^sha256:[a-fA-F0-9]{64}$' -or $asset.size -le 0 -or $asset.size -gt 25MB) {
        throw 'Invalid release asset'
    }
    return @{ Version=$number; Url=$expected; Digest=$asset.digest.Substring(7); Size=[long]$asset.size }
}

function Get-PublishedRelease([string]$Tag) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $endpoint = 'https://api.github.com/repos/Calatravo/pokemon_mods/releases/latest'
    if ($Tag) { $endpoint = "https://api.github.com/repos/Calatravo/pokemon_mods/releases/tags/v$Tag" }
    Invoke-RestMethod -Uri $endpoint -UseBasicParsing -TimeoutSec 20 -Headers @{
        'User-Agent'='Pokemon-Z-Mods-Updater'; 'Accept'='application/vnd.github+json'
    }
}

function Expand-ModPackage([string]$Archive, [string]$Destination, [string]$ExpectedVersion) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $total = 0L
        $seen = @{}
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\','/')
            if ($name -match '(^/|:|(^|/)\.\.(/|$))') { throw 'Unsafe archive path' }
            if (!$name.StartsWith('mod/HardcoreNuzlocke/')) { continue }
            $relative = $name.Substring('mod/HardcoreNuzlocke/'.Length)
            if (!$relative -or $relative.EndsWith('/')) { continue }
            if ($relative -match '(^|/)(\.|[^/]*[. ])(/|$)' -or $relative -match '[<>"|?*]') { throw 'Invalid archive filename' }
            if ($relative -eq 'Config/install_profile.rb') { continue }
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $relative))
            if (!$target.StartsWith([IO.Path]::GetFullPath($Destination) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Archive path escapes stage' }
            if ($seen.ContainsKey($target)) { throw 'Duplicate archive entry' }
            $seen[$target] = $true
            $total += $entry.Length
            if ($total -gt 50MB -or $seen.Count -gt 2000) { throw 'Package too large' }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
        }
        foreach ($required in @('loader.rb','Scripts/updater.rb','Scripts/hooks.rb','Updater/update.ps1','VERSION')) {
            if (!$seen.ContainsKey([IO.Path]::GetFullPath((Join-Path $Destination $required)))) { throw "Incomplete package: $required" }
        }
        if ((Get-ModVersion (Join-Path $Destination 'VERSION')) -ne [version]$ExpectedVersion) { throw 'Package version mismatch' }
    } finally { $zip.Dispose() }
}

function Install-StagedMod([string]$Target, [string]$Stage, [string]$Backup) {
    # All three paths must be direct children of their known directories.
    $mods = Split-Path -Parent $Target
    $updates = Join-Path $mods '.pzn-updates'
    if ((Split-Path -Leaf $Target) -cne 'HardcoreNuzlocke' -or
        !(Split-Path -Parent $Stage).StartsWith($updates + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Parent $Backup) -ne (Split-Path -Parent $Stage)) { throw 'Unsafe installation paths' }
    Move-Item -LiteralPath $Target -Destination $Backup
    try { Move-Item -LiteralPath $Stage -Destination $Target }
    catch {
        Move-Item -LiteralPath $Backup -Destination $Target
        throw
    }
}

function Write-UpdateStatus([string]$Value) {
    $temp = Join-Path $script:work 'status.tmp'
    [IO.File]::WriteAllText($temp, $Value, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination (Join-Path $script:work 'status.txt') -Force
}

function Show-UpdateMonitor {
    Add-Type -AssemblyName System.Windows.Forms
    $messages = @{
        es=@('Actualizando Pokemon Z Mods','Descargando y verificando la actualización...','Instalando la actualización...','Actualización instalada. Abriendo el juego...','No se pudo actualizar. Puedes volver a abrir el juego. Detalles:');
        en=@('Updating Pokemon Z Mods','Downloading and verifying the update...','Installing the update...','Update installed. Opening the game...','Update failed. You can open the game again. Details:');
        fr=@('Mise à jour de Pokemon Z Mods','Téléchargement et vérification...','Installation de la mise à jour...','Mise à jour installée. Ouverture du jeu...','Échec de la mise à jour. Vous pouvez relancer le jeu. Détails :')
    }
    $text = $messages[$Language]
    $form = New-Object Windows.Forms.Form
    $form.Text = $text[0]; $form.Width = 520; $form.Height = 180
    $form.StartPosition = 'CenterScreen'; $form.MaximizeBox = $false
    $label = New-Object Windows.Forms.Label
    $label.Dock = 'Fill'; $label.Padding = New-Object Windows.Forms.Padding(16)
    $label.Text = $text[1]; $form.Controls.Add($label)
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        $statusPath = Join-Path $script:work 'status.txt'
        $status = if (Test-Path -LiteralPath $statusPath) { [IO.File]::ReadAllText($statusPath) } else { '' }
        if ($status -eq 'installing') { $label.Text = $text[2] }
        if ($status -eq 'installed') { $timer.Stop(); $form.Close() }
        if ($status -eq 'failed') {
            $timer.Stop()
            $label.Text = $text[4] + "`r`n" + (Join-Path $script:work 'error.txt')
        }
    })
    $timer.Start()
    try { [void]$form.ShowDialog() } finally { $timer.Dispose(); $form.Dispose() }
}

function Invoke-ModUpdate {
    $game = (Resolve-Path -LiteralPath $GamePath).Path
    $target = Join-Path $game 'Mods\HardcoreNuzlocke'
    if (!(Test-Path -LiteralPath (Join-Path $game 'Game.exe')) -or !(Test-Path -LiteralPath (Join-Path $target 'loader.rb'))) { throw 'Game/mod not found' }
    $updates = Join-Path $game 'Mods\.pzn-updates'
    $script:work = Join-Path $updates $Session
    Assert-NoLinkedParents $script:work
    Assert-NoLinkedParents $target
    New-Item -ItemType Directory -Path $script:work -Force | Out-Null
    if ($Mode -eq 'Monitor') { Show-UpdateMonitor; return }
    $lock = $null
    try {
        $installed = Get-ModVersion (Join-Path $target 'VERSION')
        if ($Mode -eq 'Install') {
            if (!$Version) { throw 'Missing accepted version' }
            $lock = [IO.File]::Open((Join-Path $updates 'install.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
            $gameProcess = [Diagnostics.Process]::GetProcessById($GamePid)
            if ($gameProcess.MainModule.FileName -ine (Join-Path $game 'Game.exe')) { throw 'Game process mismatch' }
            Write-UpdateStatus 'closing'
            if (!$gameProcess.WaitForExit(20000)) { throw 'Game did not close; update cancelled' }
            Write-UpdateStatus 'downloading'
            $monitorArgs = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',
                ('"' + $PSCommandPath + '"'),'-Mode','Monitor','-GamePath',('"' + $game + '"'),
                '-Session',$Session,'-Language',$Language)
            Start-Process -FilePath "$PSHOME/powershell.exe" -ArgumentList $monitorArgs -WindowStyle Hidden | Out-Null
        }
        $asset = Get-ReleaseAsset (Get-PublishedRelease $(if ($Mode -eq 'Install') { $Version }))
        if ([version]$asset.Version -le $installed) {
            if ($Mode -eq 'Install') {
                Write-UpdateStatus 'installed'
                Start-Process -FilePath (Join-Path $game 'Game.exe') -WorkingDirectory $game | Out-Null
            } else { Write-UpdateStatus 'current' }
            return
        }
        if ($Mode -eq 'Check') { Write-UpdateStatus "available:$($asset.Version)"; return }
        if (!$Version -or $asset.Version -ne $Version) { throw 'Release changed' }
        $archive = Join-Path $script:work 'release.zip'
        Invoke-WebRequest -Uri $asset.Url -UseBasicParsing -TimeoutSec 60 -OutFile $archive
        Test-PackageDigest $archive $asset
        # Reject junctions before copying, so updates cannot reach outside the mod.
        $links = @(Get-Item -LiteralPath $target) + @(Get-ChildItem -LiteralPath $target -Recurse -Force)
        if ($links | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Linked mod files are unsupported' }
        $stage = Join-Path $script:work 'stage'
        if (Test-Path -LiteralPath $stage) { throw 'Stage already exists' }
        Copy-Item -LiteralPath $target -Destination $stage -Recurse
        Expand-ModPackage $archive $stage $Version
        # A second game instance must also be closed; do not replace its files.
        foreach ($process in @(Get-Process -Name Game -ErrorAction SilentlyContinue)) {
            if ($process.Path -ieq (Join-Path $game 'Game.exe')) { throw 'Another game instance is running; retry next launch' }
        }
        if ((Get-ModVersion (Join-Path $target 'VERSION')) -ne $installed) { throw 'Installed version changed during download' }
        Write-UpdateStatus 'installing'
        Install-StagedMod $target $stage (Join-Path $script:work 'backup')
        Write-UpdateStatus 'installed'
        Start-Process -FilePath (Join-Path $game 'Game.exe') -WorkingDirectory $game | Out-Null
    } catch {
        [IO.File]::WriteAllText((Join-Path $script:work 'error.txt'), $_.Exception.Message)
        Write-UpdateStatus 'failed'
    } finally { if ($lock) { $lock.Dispose() } }
}

# Dot sourcing exposes the bounded functions for offline regression tests.
if ($MyInvocation.InvocationName -ne '.') { Invoke-ModUpdate }
