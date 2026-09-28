$ErrorActionPreference = 'Stop'
$output = Join-Path ([IO.Path]::GetTempPath()) ('pz-android-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $output | Out-Null
try {
    & javac -encoding UTF-8 -d $output "$PSScriptRoot/src/org/pokemonzmods/installer/InstallLogic.java" "$PSScriptRoot/src/org/pokemonzmods/installer/InstallTransaction.java" "$PSScriptRoot/tests/InstallerTest.java"
    if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed' }
    & java -cp $output InstallerTest
    if ($LASTEXITCODE -ne 0) { throw 'Android installer tests failed' }
}
finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ([IO.Path]::GetFullPath($output).StartsWith($tempRoot)) { Remove-Item -LiteralPath $output -Recurse -Force }
}
