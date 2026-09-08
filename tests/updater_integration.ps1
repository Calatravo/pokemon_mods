# Uses the shipped Ruby 1.8 runtime and real process exit, with an offline release fixture.
param([string]$GameFolder = "$PSScriptRoot/../Pokemon Z V2.18")
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$fixture = Join-Path $env:TEMP ('pzn-update-integration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$fixture/Mods" -Force | Out-Null
Copy-Item -LiteralPath "$GameFolder/Game.exe","$GameFolder/Game.ini" -Destination $fixture
Get-ChildItem -LiteralPath $GameFolder -Filter '*.dll' | Copy-Item -Destination $fixture
Copy-Item -LiteralPath "$repo/mod/HardcoreNuzlocke" -Destination "$fixture/Mods" -Recurse
[IO.File]::WriteAllText("$fixture/mkxp.json", '{"rgssVersion":1,"customScript":"test.rb"}')
[IO.File]::WriteAllText("$fixture/Mods/HardcoreNuzlocke/VERSION", '1.0.4')
[IO.File]::WriteAllText("$fixture/Mods/HardcoreNuzlocke/Config/install_profile.rb", '# preserve my profile')
[IO.File]::WriteAllText("$fixture/save-sentinel.txt", 'save untouched')
$version = [IO.File]::ReadAllText("$repo/VERSION").Trim()
$archive = "$repo/dist/Pokemon-Z-Mods-v$version.zip"
$size = (Get-Item -LiteralPath $archive).Length
$hash = (Get-FileHash -LiteralPath $archive).Hash
$wrapper = @'
param($Mode,$GamePath,$Session,$GamePid,$Version,$Language)
. '__HELPER__' -Mode $Mode -GamePath $GamePath -Session $Session -GamePid $GamePid -Version $Version -Language $Language
function Get-PublishedRelease {
    if (Get-Process -Id $GamePid -ErrorAction SilentlyContinue) { throw 'Network started before game exit' }
    return @{ tag_name=('v' + $Version); draft=$false; prerelease=$false; assets=@(@{
        name="Pokemon-Z-Mods-v$Version.zip"; state='uploaded'; size=__SIZE__;
        digest='sha256:__HASH__';
        browser_download_url="https://github.com/Calatravo/pokemon_mods/releases/download/v$Version/Pokemon-Z-Mods-v$Version.zip"
    }) }
}
function Invoke-WebRequest {
    param($Uri,[switch]$UseBasicParsing,$TimeoutSec,$OutFile)
    Start-Sleep -Milliseconds 500
    Copy-Item -LiteralPath '__ARCHIVE__' -Destination $OutFile
}
function Start-Process {
    param($FilePath,$WorkingDirectory,$ArgumentList,$WindowStyle)
    if ($FilePath -like '*Game.exe') { [IO.File]::WriteAllText((Join-Path $GamePath 'reopened.txt'), 'requested') }
}
Invoke-ModUpdate
'@
$wrapper = $wrapper.Replace('__HELPER__', ("$repo/mod/HardcoreNuzlocke/Updater/update.ps1".Replace("'","''"))).Replace('__SIZE__',"$size").Replace('__HASH__',$hash).Replace('__ARCHIVE__',$archive.Replace("'","''"))
[IO.File]::WriteAllText("$fixture/Mods/HardcoreNuzlocke/Updater/update.ps1",$wrapper,[Text.UTF8Encoding]::new($true))
$ruby = @'
PZ_HARDCORE_NUZLOCKE_ROOT = File.expand_path('Mods/HardcoreNuzlocke')
module PZHardcoreNuzlocke
  def self.language; :es; end
  def self.log(message); File.open('ruby-error.txt','a') { |f| f.puts message }; end
end
begin
  load 'Mods/HardcoreNuzlocke/Scripts/updater.rb'
  session = "#{Process.pid}-#{Time.now.to_i}"
  PZHardcoreNuzlocke.instance_variable_set(:@update_session, session)
  PZHardcoreNuzlocke.launch_update_worker('Install', '__VERSION__')
  deadline = Time.now + 15
  while Time.now < deadline
    Graphics.update
    path = "Mods/.pzn-updates/#{session}/status.txt"
    exit! if File.exist?(path) && File.read(path) == 'closing'
  end
  raise 'Worker did not acknowledge game closure'
rescue Exception => error
  PZHardcoreNuzlocke.log(error.message)
ensure
  exit!
end
'@
[IO.File]::WriteAllText("$fixture/test.rb",$ruby.Replace('__VERSION__',$version))
$process = Start-Process -FilePath "$fixture/Game.exe" -WorkingDirectory $fixture -WindowStyle Hidden -PassThru
if (!$process.WaitForExit(25000)) { throw "Fixture game did not exit: $fixture" }
$deadline = [DateTime]::UtcNow.AddSeconds(20)
do {
    Start-Sleep -Milliseconds 200
    $statuses = @(Get-ChildItem -LiteralPath "$fixture/Mods/.pzn-updates" -Filter status.txt -Recurse -ErrorAction SilentlyContinue)
    $state = if ($statuses.Count) { [IO.File]::ReadAllText($statuses[0].FullName) } else { '' }
} while ($state -notin @('installed','failed') -and [DateTime]::UtcNow -lt $deadline)
if ($state -ne 'installed') { throw "Integration failed ($state), inspect $fixture" }
if ([IO.File]::ReadAllText("$fixture/Mods/HardcoreNuzlocke/VERSION").Trim() -ne $version -or
    [IO.File]::ReadAllText("$fixture/Mods/HardcoreNuzlocke/Config/install_profile.rb") -ne '# preserve my profile' -or
    [IO.File]::ReadAllText("$fixture/save-sentinel.txt") -ne 'save untouched' -or
    !(Test-Path -LiteralPath "$fixture/reopened.txt")) { throw "Integration verification failed: $fixture" }
Write-Output "PASS native Ruby 1.8 launch, automatic exit before network, verified install, profile/save preservation, reopen request: $fixture"
