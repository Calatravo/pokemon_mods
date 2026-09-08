$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../mod/HardcoreNuzlocke/Updater/update.ps1"
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('pzn-update-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:checks = 0
function Assert($Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
    $script:checks++
}
function Reject([scriptblock]$Action) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    Assert $rejected 'Expected rejection'
}
function New-Package([string]$Path, [hashtable]$Entries) {
    $zip = [IO.Compression.ZipFile]::Open($Path, 'Create')
    try {
        foreach ($name in $Entries.Keys) {
            $entry = $zip.CreateEntry($name)
            $writer = [IO.StreamWriter]::new($entry.Open())
            try { $writer.Write($Entries[$name]) } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose() }
}
try {
    $release = @{ tag_name='v1.2.0'; draft=$false; prerelease=$false; assets=@(@{
        name='Pokemon-Z-Mods-v1.2.0.zip'; state='uploaded'; size=500;
        browser_download_url='https://github.com/Calatravo/pokemon_mods/releases/download/v1.2.0/Pokemon-Z-Mods-v1.2.0.zip';
        digest=('sha256:' + ('a' * 64))
    }) }
    Assert ((Get-ReleaseAsset $release).Version -eq '1.2.0') 'Stable release rejected'
    $release.prerelease=$true; Reject { Get-ReleaseAsset $release }; $release.prerelease=$false
    $release.assets[0].digest=''; Reject { Get-ReleaseAsset $release }; $release.assets[0].digest='sha256:' + ('a' * 64)
    $release.assets[0].browser_download_url='https://example.com/untrusted.zip'; Reject { Get-ReleaseAsset $release }

    $mods = Join-Path $fixture 'Mods'
    $target = Join-Path $mods 'HardcoreNuzlocke'
    $workDir = Join-Path $mods '.pzn-updates\123-456'
    $stage = Join-Path $workDir 'stage'
    New-Item -ItemType Directory -Path "$target/Config",$stage -Force | Out-Null
    [IO.File]::WriteAllText("$target/Config/install_profile.rb", 'my French profile')
    [IO.File]::WriteAllText("$target/VERSION", '1.1.0')
    [IO.File]::WriteAllText("$target/old.txt", 'keep me')
    Copy-Item -Path "$target/*" -Destination $stage -Recurse
    $entries = @{
        'mod/HardcoreNuzlocke/loader.rb'='new loader';
        'mod/HardcoreNuzlocke/VERSION'='1.2.0';
        'mod/HardcoreNuzlocke/Scripts/updater.rb'='new updater';
        'mod/HardcoreNuzlocke/Scripts/hooks.rb'='new hooks';
        'mod/HardcoreNuzlocke/Updater/update.ps1'='new worker';
        'mod/HardcoreNuzlocke/Config/install_profile.rb'='wrong profile';
        'install.ps1'='must never execute'; 'Data/Scripts.rxdata'='must never install'
    }
    $archive = Join-Path $fixture 'valid.zip'
    New-Package $archive $entries
    $verified = @{ Size=(Get-Item -LiteralPath $archive).Length; Digest=(Get-FileHash -LiteralPath $archive).Hash }
    Test-PackageDigest $archive $verified
    $verified.Digest = '0' * 64
    Reject { Test-PackageDigest $archive $verified }
    Expand-ModPackage $archive $stage '1.2.0'
    Assert ([IO.File]::ReadAllText("$stage/Config/install_profile.rb") -eq 'my French profile') 'Profile changed'
    Assert (!(Test-Path "$fixture/Data")) 'Game data extracted'
    Assert ([IO.File]::ReadAllText("$target/VERSION") -eq '1.1.0') 'Live mod changed during staging'
    $backup = Join-Path $workDir 'backup'
    Install-StagedMod $target $stage $backup
    Assert ([IO.File]::ReadAllText("$target/VERSION") -eq '1.2.0') 'Update failed'
    Assert ([IO.File]::ReadAllText("$backup/VERSION") -eq '1.1.0') 'Backup missing'
    Assert ([IO.File]::ReadAllText("$target/old.txt") -eq 'keep me') 'Local files lost'
    Reject { Install-StagedMod $target (Join-Path $workDir 'missing') (Join-Path $workDir 'rollback') }
    Assert (Test-Path "$target/loader.rb") 'Rollback failed'
    Reject { Install-StagedMod $target $fixture (Join-Path $workDir 'unsafe') }
    $bad = Join-Path $fixture 'bad.zip'
    New-Package $bad @{ 'mod/HardcoreNuzlocke/../../escape.txt'='bad' }
    Reject { Expand-ModPackage $bad (Join-Path $workDir 'badstage') '1.2.0' }
    Assert (!(Test-Path "$mods/escape.txt")) 'Traversal escaped stage'
    Reject { Expand-ModPackage $archive (Join-Path $workDir 'wrongversion') '1.3.0' }
    $empty = Join-Path $fixture 'empty.zip'
    New-Package $empty @{ 'mod/HardcoreNuzlocke/VERSION'='1.2.0' }
    Reject { Expand-ModPackage $empty (Join-Path $workDir 'incomplete') '1.2.0' }
    Assert ([version]'1.10.0' -gt [version]'1.9.0') 'Version ordering'
    [IO.File]::WriteAllText((Join-Path $fixture 'Game.exe'), '')
    $GamePath = $fixture; $Session = '789-012'; $Mode = 'Check'
    function Get-PublishedRelease { throw 'Simulated offline connection' }
    Invoke-ModUpdate
    Assert ([IO.File]::ReadAllText((Join-Path $mods '.pzn-updates/789-012/status.txt')) -eq 'failed') 'Offline check did not finish safely'
    Assert ([IO.File]::ReadAllText("$target/VERSION") -eq '1.2.0') 'Offline check changed installed files'
    Write-Output "PASS $script:checks Windows updater checks"
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    if (!$resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolved) -notlike 'pzn-update-tests-*') { throw 'Unsafe test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
