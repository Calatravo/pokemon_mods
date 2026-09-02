[CmdletBinding()]
param(
    [string]$DistPath
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $DistPath) {
    $DistPath = Join-Path $projectRoot "dist"
}
$version = [System.IO.File]::ReadAllText((Join-Path $projectRoot "VERSION")).Trim()
$dist = (Resolve-Path -LiteralPath $DistPath).Path

$expectedProfiles = @{
    "ES-2.18" = @("LANGUAGE = :es", "PROFILE = :es_218")
    "EN-2.13" = @("LANGUAGE = :en", "PROFILE = :en_213")
    "FR-2.12-Patch1" = @("LANGUAGE = :fr", "PROFILE = :fr_212p1")
}

$expectedArchives = @("Pokemon-Z-Mods-v$version.zip") + @(
    $expectedProfiles.Keys | ForEach-Object { "Pokemon-Z-Mods-v$version-Android-JoiPlay-$_.zip" }
)
foreach ($archiveName in $expectedArchives) {
    if (-not (Test-Path -LiteralPath (Join-Path $dist $archiveName) -PathType Leaf)) {
        throw "Missing release archive: $archiveName"
    }
}

$checksumPath = Join-Path $dist "SHA256SUMS.txt"
$checksumLines = [System.IO.File]::ReadAllLines($checksumPath)
foreach ($line in $checksumLines) {
    $parts = $line -split '\s+', 2
    if ($parts.Count -ne 2) {
        throw "Invalid checksum line: $line"
    }
    $archivePath = Join-Path $dist $parts[1]
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $parts[0]) {
        throw "Checksum mismatch: $($parts[1])"
    }
}
Write-Host "PASS checksums"

Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($archiveName in $expectedArchives) {
    $archivePath = Join-Path $dist $archiveName
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $forbidden = $zip.Entries | Where-Object {
            $_.FullName -match '(?i)\.(rxdata|rvdata|rvdata2|exe|dll|sav|dat)$'
        }
        if ($forbidden) {
            throw "Forbidden game/save content in ${archiveName}: $($forbidden.FullName -join ', ')"
        }

        if ($archiveName -eq "Pokemon-Z-Mods-v$version.zip") {
            foreach ($entryName in @(
                "Install Pokemon Z Mods.cmd",
                "install.ps1",
                "install.sh",
                "installer/install.py",
                "installer/install-gui.ps1",
                "mod/HardcoreNuzlocke/loader.rb",
                "PLATFORMS.md"
            )) {
                if (-not $zip.GetEntry($entryName)) {
                    throw "Universal archive is missing: $entryName"
                }
            }
        }
        else {
            $edition = $expectedProfiles.Keys | Where-Object { $archiveName.EndsWith("-$_.zip") }
            if (-not $edition) {
                throw "Unexpected Android archive name: $archiveName"
            }
            $profileEntry = $zip.GetEntry("Mods/HardcoreNuzlocke/Config/install_profile.rb")
            if (-not $profileEntry -or -not $zip.GetEntry("preload.rb") -or -not $zip.GetEntry("ANDROID-README.txt")) {
                throw "Android overlay is incomplete: $archiveName"
            }
            $reader = New-Object System.IO.StreamReader($profileEntry.Open())
            try {
                $profileText = $reader.ReadToEnd()
            }
            finally {
                $reader.Dispose()
            }
            foreach ($expectedLine in $expectedProfiles[$edition]) {
                if (-not $profileText.Contains($expectedLine)) {
                    throw "Android profile $edition is missing: $expectedLine"
                }
            }
        }
    }
    finally {
        $zip.Dispose()
    }
    Write-Host "PASS $archiveName"
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pokemon-z-mod-release-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $packageRoot = Join-Path $testRoot "package"
    Expand-Archive -LiteralPath (Join-Path $dist "Pokemon-Z-Mods-v$version.zip") -DestinationPath $packageRoot

    $sourceGame = Join-Path $projectRoot "Pokemon Z V2.18"
    $targetGame = Join-Path $testRoot "Pokemon Z V2.18"
    New-Item -ItemType Directory -Path (Join-Path $targetGame "Data") -Force | Out-Null
    foreach ($relativePath in @("Game.exe", "preload.rb", "mkxp.json", "Data\Scripts.rxdata")) {
        Copy-Item -LiteralPath (Join-Path $sourceGame $relativePath) -Destination (Join-Path $targetGame $relativePath)
    }
    $scriptsPath = Join-Path $targetGame "Data\Scripts.rxdata"
    $scriptsHashBefore = (Get-FileHash -LiteralPath $scriptsPath -Algorithm SHA256).Hash
    & python (Join-Path $packageRoot "installer\install.py") $targetGame --profile es_218
    if ($LASTEXITCODE -ne 0) {
        throw "The installer in the universal release archive failed."
    }
    $scriptsHashAfter = (Get-FileHash -LiteralPath $scriptsPath -Algorithm SHA256).Hash
    if ($scriptsHashBefore -ne $scriptsHashAfter) {
        throw "The packaged installer changed Data/Scripts.rxdata."
    }
    if (-not (Test-Path -LiteralPath (Join-Path $targetGame "Mods\HardcoreNuzlocke\loader.rb"))) {
        throw "The packaged installer did not copy the mod."
    }
    Write-Host "PASS packaged installer; Scripts.rxdata unchanged"
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path
        $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd("\")
        if (-not $resolvedTestRoot.StartsWith($tempRoot + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe temporary cleanup path: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}

Write-Host "PASS release validation complete"
