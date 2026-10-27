[CmdletBinding()]
param([switch]$GameDetection)

$ErrorActionPreference = 'Stop'
$output = Join-Path ([IO.Path]::GetTempPath()) ('pz-android-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $output | Out-Null
try {
    & javac -encoding UTF-8 -d $output "$PSScriptRoot/src/org/pokemonzmods/installer/InstallLogic.java" "$PSScriptRoot/src/org/pokemonzmods/installer/InstallTransaction.java" "$PSScriptRoot/tests/InstallerTest.java"
    if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed' }
    $fixtures = @()
    if ($GameDetection) {
        $repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        foreach ($case in @(
            @{ Folder = 'Pokemon Z V2.18'; Edition = 0 },
            @{ Folder = 'Pokemon Z V2.19'; Edition = 0 },
            @{ Folder = 'POKEMON Z V2.13\Pokemon Z V2.13'; Edition = 1 },
            @{ Folder = 'Pokémon Z V2.12 - Français'; Edition = 2 }
        )) {
            $scripts = Join-Path $repo "$($case.Folder)\Data\Scripts.rxdata"
            if (-not (Test-Path -LiteralPath $scripts -PathType Leaf)) { throw "Missing game detection fixture: $scripts" }
            $fixtures += @([string]$case.Edition, $scripts)
        }
    }
    & java -cp $output InstallerTest @fixtures
    if ($LASTEXITCODE -ne 0) { throw 'Android installer tests failed' }
}
finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ([IO.Path]::GetFullPath($output).StartsWith($tempRoot)) { Remove-Item -LiteralPath $output -Recurse -Force }
}
