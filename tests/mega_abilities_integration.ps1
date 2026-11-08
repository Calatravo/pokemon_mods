# Exercise native Mega Evolution, form abilities and battle updates without saving.
[CmdletBinding()]
param(
    [string]$GameFolder = "$PSScriptRoot/../Pokemon Z V2.18",
    [switch]$Unpatched
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$game = (Resolve-Path -LiteralPath $GameFolder).Path
$fixture = Join-Path $env:TEMP ('pzn-mega-abilities-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item -LiteralPath "$game/Game.exe", "$game/Game.ini" -Destination $fixture
Get-ChildItem -LiteralPath $game -Filter '*.dll' | Copy-Item -Destination $fixture
$config = @{rgssVersion=1; gameFolder=$game; customScript="$fixture/test.rb"}
[IO.File]::WriteAllText("$fixture/mkxp.json", ($config | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
$ruby = @'
log = File.open('__FIXTURE__/result.txt', 'wb')
log.sync = true
$stdout = log
begin
  puts "Ruby #{RUBY_VERSION}"
  Dir.chdir('__GAME__')
  load_data('Data/Scripts.rxdata').each do |entry|
    name = entry[1].to_s
    next if name == 'Main' || name == 'PZ Hardcore Nuzlocke Bridge'
    source = defined?(MKXP) && MKXP.respond_to?(:zinflate) ? MKXP.zinflate(entry[2]) : Zlib::Inflate.inflate(entry[2])
    eval(source, TOPLEVEL_BINDING, name)
  end
  messages = Messages.new
  messages.instance_variable_set(:@messages, load_data('Data/messages.dat'))
  MessageTypes.send(:class_variable_set, :@@messages, messages)
  module PZHardcoreNuzlocke
    def self.log(message); puts message; end
    def self.random_state; @test_config; end
    def self.test_config=(value); @test_config = value; end
  end
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/random.rb'
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/hooks.rb'
  module PZHardcoreNuzlocke
    def self.random_state; @test_config; end
  end
  ENV['PZN_MEGA_UNPATCHED'] = '__UNPATCHED__'
  load '__REPO__/tests/mega_abilities_test.rb'
  puts 'RESULT PASS'
rescue Exception => error
  puts "RESULT FAIL: #{error.class}: #{error.message}"
  puts error.backtrace
ensure
  log.close
  exit!
end
'@
$ruby = $ruby.Replace('__FIXTURE__', $fixture.Replace('\','/')).Replace('__GAME__', $game.Replace('\','/')).Replace('__REPO__', $repo.Replace('\','/')).Replace('__UNPATCHED__', $(if ($Unpatched) {'1'} else {'0'}))
[IO.File]::WriteAllText("$fixture/test.rb", $ruby, [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage))
$process = Start-Process -FilePath "$fixture/Game.exe" -WorkingDirectory $fixture -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(30000)) {
    Stop-Process -Id $process.Id -Force
    throw "Mega ability integration timed out; inspect $fixture"
}
$result = [IO.File]::ReadAllText("$fixture/result.txt")
Write-Output $result
if (-not $result.Contains('RESULT PASS')) { throw "Mega ability integration failed; inspect $fixture" }
$resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
$resolvedTemp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $resolvedFixture) -notlike 'pzn-mega-abilities-*') {
    throw "Unsafe test cleanup path: $resolvedFixture"
}
Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
