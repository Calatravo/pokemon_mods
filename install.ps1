[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GamePath
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceMod = Join-Path $projectRoot "mod\HardcoreNuzlocke"
$snippetPath = Join-Path $projectRoot "installer\preload-snippet.rb"

if (-not (Test-Path -LiteralPath $GamePath -PathType Container)) {
    throw "No existe la carpeta del juego: $GamePath"
}

$resolvedGamePath = (Resolve-Path -LiteralPath $GamePath).Path
$gameExe = Join-Path $resolvedGamePath "Game.exe"
$preloadPath = Join-Path $resolvedGamePath "preload.rb"
$scriptsPath = Join-Path $resolvedGamePath "Data\Scripts.rxdata"

foreach ($requiredPath in @($gameExe, $preloadPath, $scriptsPath, $sourceMod, $snippetPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Falta un archivo o carpeta necesaria: $requiredPath"
    }
}

$targetMod = Join-Path $resolvedGamePath "Mods\HardcoreNuzlocke"
New-Item -ItemType Directory -Path $targetMod -Force | Out-Null
Get-ChildItem -LiteralPath $sourceMod -Force | Copy-Item -Destination $targetMod -Recurse -Force

$backupPath = "$preloadPath.backup-before-pokemon-mods"
if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $preloadPath -Destination $backupPath
    Write-Host "Copia de seguridad creada: $backupPath"
}

$preloadText = [System.IO.File]::ReadAllText($preloadPath)
$snippetText = [System.IO.File]::ReadAllText($snippetPath).Trim()
$markerPattern = '(?ms)^\s*# BEGIN POKEMON_MODS HARDCORE_NUZLOCKE\s*$.*?^\s*# END POKEMON_MODS HARDCORE_NUZLOCKE\s*\r?\n?'
$preloadText = [System.Text.RegularExpressions.Regex]::Replace($preloadText, $markerPattern, "").TrimEnd()
$updatedPreload = $preloadText + [Environment]::NewLine + [Environment]::NewLine + $snippetText + [Environment]::NewLine
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($preloadPath, $updatedPreload, $utf8WithoutBom)

Write-Host ""
Write-Host "Pokemon Z Mods se ha instalado correctamente." -ForegroundColor Green
Write-Host "Juego: $resolvedGamePath"
Write-Host "Mod:   $targetMod"
Write-Host ""
Write-Host "Inicia Game.exe. Tras llegar al menu principal, revisa este registro:"
Write-Host (Join-Path $targetMod "nuzlocke.log")
Write-Host "La validacion correcta termina con: PASS (12 hooks)"
