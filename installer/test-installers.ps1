[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("pokemon-z-mod-installer-test-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null

$cases = @(
    @{ Source = "Pokemon Z V2.18"; Target = "Edition A"; Profile = "es_218"; Language = "es" },
    @{ Source = "Pokemon Z V2.19"; Target = "Edition D"; Profile = "es_218"; Language = "es" },
    @{ Source = "Pokemon Z V2.19"; Target = "Pokemon Z V2.19"; Profile = "es_218"; Language = "es"; UnknownHash = $true },
    @{ Source = "POKEMON Z V2.13\Pokemon Z V2.13"; Target = "Edition B"; Profile = "en_213"; Language = "en" },
    @{ Source = "Pokémon Z V2.12 - Français"; Target = "Edition C"; Profile = "fr_212p1"; Language = "fr" }
)

try {
    foreach ($case in $cases) {
        $source = Join-Path $projectRoot $case.Source
        $target = Join-Path $testRoot $case.Target
        New-Item -ItemType Directory -Path (Join-Path $target "Data") -Force | Out-Null
        foreach ($relativePath in @("Game.exe", "mkxp.json", "Data\Scripts.rxdata")) {
            Copy-Item -LiteralPath (Join-Path $source $relativePath) -Destination (Join-Path $target $relativePath)
        }
        $originalPreload = Join-Path $source "preload.rb.backup-before-pokemon-mods"
        if (-not (Test-Path -LiteralPath $originalPreload -PathType Leaf)) {
            $originalPreload = Join-Path $source "preload.rb"
        }
        Copy-Item -LiteralPath $originalPreload -Destination (Join-Path $target "preload.rb")

        $scriptsPath = Join-Path $target "Data\Scripts.rxdata"
        if ($case.UnknownHash) {
            # Exercise the folder-name fallback independently of known hashes.
            $stream = [System.IO.File]::OpenWrite($scriptsPath)
            try {
                $stream.Seek(0, [System.IO.SeekOrigin]::End) | Out-Null
                $stream.WriteByte(0)
            }
            finally { $stream.Dispose() }
        }
        $scriptsHashBefore = (Get-FileHash -LiteralPath $scriptsPath -Algorithm SHA256).Hash
        foreach ($installer in @("Python", "Python", "PowerShell", "PowerShell")) {
            if ($installer -eq "Python") {
                & python (Join-Path $PSScriptRoot "install.py") $target
                if ($LASTEXITCODE -ne 0) { throw "Python installation failed for $($case.Source)." }
            }
            else {
                & (Join-Path $projectRoot "install.ps1") -GamePath $target -Language auto
            }
            $installedProfile = [System.IO.File]::ReadAllText((Join-Path $target "Mods\HardcoreNuzlocke\Config\install_profile.rb"))
            if ($installedProfile -notmatch "LANGUAGE = :$($case.Language)" -or $installedProfile -notmatch "PROFILE = :$($case.Profile)") {
                throw "$installer selected the wrong profile for $($case.Source)."
            }
        }

        $preload = [System.IO.File]::ReadAllText((Join-Path $target "preload.rb"))
        $profile = [System.IO.File]::ReadAllText((Join-Path $target "Mods\HardcoreNuzlocke\Config\install_profile.rb"))
        $mkxp = [System.IO.File]::ReadAllText((Join-Path $target "mkxp.json"))
        $loaderCount = ([regex]::Matches($preload, "Mods.*HardcoreNuzlocke.*loader\.rb", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
        $preloadEntryCount = ([regex]::Matches($mkxp, '(?m)^(?!\s*//)\s*"preloadScript"\s*:\s*\[[^\]]*"preload\.rb"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
        $scriptsHashAfter = (Get-FileHash -LiteralPath $scriptsPath -Algorithm SHA256).Hash

        $checks = @(
            ($loaderCount -eq 1),
            ($preloadEntryCount -eq 1),
            ($profile -match "LANGUAGE = :$($case.Language)"),
            ($profile -match "PROFILE = :$($case.Profile)"),
            (Test-Path -LiteralPath (Join-Path $target "preload.rb.backup-before-pokemon-mods")),
            (Test-Path -LiteralPath (Join-Path $target "mkxp.json.backup-before-pokemon-mods")),
            ($scriptsHashBefore -eq $scriptsHashAfter)
        )
        if ($checks -contains $false) {
            throw "Validation failed for $($case.Profile): loader entries=$loaderCount, preload entries=$preloadEntryCount."
        }
        Write-Host "PASS $($case.Source) as $($case.Target): Python/PowerShell auto-detection, idempotency, backups, unchanged Scripts.rxdata"
    }
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

Write-Host "PASS temporary cleanup"
