[CmdletBinding()]
param(
    [string]$Version,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Version) {
    $Version = [System.IO.File]::ReadAllText((Join-Path $projectRoot "VERSION")).Trim()
}
if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
    throw "Invalid release version: $Version"
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRoot "dist"
}
$expectedDefaultOutput = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "dist"))
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
if ($resolvedOutput -eq [System.IO.Path]::GetPathRoot($resolvedOutput)) {
    throw "Refusing to use a filesystem root as the output path."
}
if ((Test-Path -LiteralPath $resolvedOutput) -and $resolvedOutput -eq $expectedDefaultOutput) {
    Remove-Item -LiteralPath $resolvedOutput -Recurse -Force
}
elseif (Test-Path -LiteralPath $resolvedOutput) {
    throw "Output path already exists. Remove it explicitly or use the default dist folder: $resolvedOutput"
}
New-Item -ItemType Directory -Path $resolvedOutput | Out-Null

$workRoot = Join-Path $resolvedOutput ".release-stage"
New-Item -ItemType Directory -Path $workRoot | Out-Null
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

function Copy-TreeContents {
    param([string]$Source, [string]$Destination)
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Destination -Recurse -Force
}

function Compress-Stage {
    param([string]$StagePath, [string]$ArchivePath)

    $forbidden = Get-ChildItem -LiteralPath $StagePath -Recurse -File | Where-Object {
        $_.Extension -match '^\.(rxdata|rvdata|rvdata2|exe|dll|sav|dat)$'
    }
    if ($forbidden) {
        throw "A release stage contains forbidden game/save files: $($forbidden.FullName -join ', ')"
    }
    Compress-Archive -Path (Join-Path $StagePath "*") -DestinationPath $ArchivePath -CompressionLevel Optimal
}

function Write-InstallProfile {
    param(
        [string]$TargetMod,
        [string]$Language,
        [string]$Profile
    )

    $profileText = @"
# encoding: UTF-8

# Generated for the Pokemon Z Mods Android/JoiPlay release package.
module PZHardcoreNuzlocke
  module InstallConfig
    LANGUAGE = :$Language
    PROFILE = :$Profile
  end
end
"@
    [System.IO.File]::WriteAllText(
        (Join-Path $TargetMod "Config\install_profile.rb"),
        $profileText,
        $utf8WithoutBom
    )
}

try {
    $universalStage = Join-Path $workRoot "universal"
    New-Item -ItemType Directory -Path $universalStage | Out-Null
    foreach ($file in @(
        "VERSION",
        "Install Pokemon Z Mods.cmd",
        "install.ps1",
        "install.sh",
        "README.md",
        "README.en.md",
        "README.fr.md",
        "INSTALL.md",
        "PLATFORMS.md",
        "LICENSE"
    )) {
        $source = Join-Path $projectRoot $file
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $universalStage $file)
        }
    }
    Copy-TreeContents (Join-Path $projectRoot "mod") (Join-Path $universalStage "mod")
    New-Item -ItemType Directory -Path (Join-Path $universalStage "installer") | Out-Null
    foreach ($file in @("preload-snippet.rb", "install-gui.ps1", "install.py")) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $universalStage "installer\$file")
    }

    $trackedScreenshots = & git -C $projectRoot ls-files "docs/screenshots/*"
    foreach ($relativePath in $trackedScreenshots) {
        $destination = Join-Path $universalStage $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $projectRoot $relativePath) -Destination $destination
    }

    $universalArchive = Join-Path $resolvedOutput "Pokemon-Z-Mods-v$Version.zip"
    Compress-Stage $universalStage $universalArchive

    $androidPackages = @(
        @{ Suffix = "ES-2.18"; Language = "es"; Profile = "es_218" },
        @{ Suffix = "EN-2.13"; Language = "en"; Profile = "en_213" },
        @{ Suffix = "FR-2.12-Patch1"; Language = "fr"; Profile = "fr_212p1" }
    )
    foreach ($package in $androidPackages) {
        $androidStage = Join-Path $workRoot ("android-" + $package.Profile)
        $targetMod = Join-Path $androidStage "Mods\HardcoreNuzlocke"
        Copy-TreeContents (Join-Path $projectRoot "mod\HardcoreNuzlocke") $targetMod
        Write-InstallProfile $targetMod $package.Language $package.Profile
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot "preload-snippet.rb") -Destination (Join-Path $androidStage "preload.rb")
        Copy-Item -LiteralPath (Join-Path $projectRoot "PLATFORMS.md") -Destination (Join-Path $androidStage "PLATFORMS.md")

        $androidReadme = @"
Pokemon Z Mods v$Version - Android/JoiPlay $($package.Suffix)

This archive is an overlay for an existing, matching Pokemon Z installation.
It does not contain the game. Back up your save and preload.rb first.

Extract this archive into the folder that directly contains Game.exe.
Merge the Mods folder and replace preload.rb, then fully restart JoiPlay.

See PLATFORMS.md for Spanish, English and French instructions.
"@
        [System.IO.File]::WriteAllText((Join-Path $androidStage "ANDROID-README.txt"), $androidReadme, $utf8WithoutBom)

        $androidArchive = Join-Path $resolvedOutput "Pokemon-Z-Mods-v$Version-Android-JoiPlay-$($package.Suffix).zip"
        Compress-Stage $androidStage $androidArchive
    }

    $archives = Get-ChildItem -LiteralPath $resolvedOutput -Filter "*.zip" -File | Sort-Object Name
    $checksumLines = foreach ($archive in $archives) {
        $hash = (Get-FileHash -LiteralPath $archive.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$hash  $($archive.Name)"
    }
    [System.IO.File]::WriteAllLines((Join-Path $resolvedOutput "SHA256SUMS.txt"), $checksumLines, $utf8WithoutBom)
}
finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}

Get-ChildItem -LiteralPath $resolvedOutput -File | Sort-Object Name | Select-Object Name, Length
