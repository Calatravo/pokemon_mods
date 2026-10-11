# Uses the shipped Ruby runtime and real game data without running Main or saving.
[CmdletBinding()]
param(
    [string]$GameFolder = "$PSScriptRoot/../Pokemon Z V2.18",
    [switch]$Unpatched
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$game = (Resolve-Path -LiteralPath $GameFolder).Path
$fixture = Join-Path $env:TEMP ('pzn-type-integration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item -LiteralPath "$game/Game.exe", "$game/Game.ini" -Destination $fixture
Get-ChildItem -LiteralPath $game -Filter '*.dll' | Copy-Item -Destination $fixture
$config = @{rgssVersion=1; gameFolder=$game; customScript="$fixture/test.rb"}
[IO.File]::WriteAllText("$fixture/mkxp.json", ($config | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
$ruby = @'
log = File.open('__FIXTURE__/result.txt', 'wb')
begin
  log.puts "Ruby #{RUBY_VERSION}"
  Dir.chdir('__GAME__')
  scripts = File.open('Data/Scripts.rxdata', 'rb') { |file| Marshal.load(file) }
  scripts.each do |entry|
    name = entry[1].to_s
    next if name == 'Main' || name == 'PZ Hardcore Nuzlocke Bridge'
    source = defined?(MKXP) && MKXP.respond_to?(:zinflate) ? MKXP.zinflate(entry[2]) : Zlib::Inflate.inflate(entry[2])
    eval(source, TOPLEVEL_BINDING, name)
  end
  module PZHardcoreNuzlocke
    def self.log(message); end
  end
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/random.rb'
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/hooks.rb'
  PZHardcoreNuzlocke.install_random_type_hooks unless '__UNPATCHED__' == '1'
  $game_temp = Game_Temp.new
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $PokemonGlobal = PokemonGlobalMetadata.new
  $Trainer = PokeBattle_Trainer.new('Type test', 0)
  starter = PokeBattle_Pokemon.new(PBSpecies::BULBASAUR, 5, $Trainer)
  bidoof = PokeBattle_Pokemon.new(PBSpecies::BIDOOF, 2)
  eevee = PokeBattle_Pokemon.new(PBSpecies::EEVEE, 5)
  $Trainer.party = [starter]
  $game_switches[409] = true
  $PokemonGlobal.enable_random_types = true
  $PokemonGlobal.semi_random = false
  $PokemonGlobal.random_types = {}
  # Keep abilities and moves ordinary to isolate the reported type failure.
  $PokemonGlobal.random_ability_mode = :NO_RANDOM
  $PokemonGlobal.enable_random_moves = false
  battle = PokeBattle_Battle.new(Object.new, [starter], [bidoof], $Trainer, nil)
  battle.battlers[0].pbInitPokemon(starter, 0)
  battle.battlers[1].pbInitPokemon(bidoof, 0)
  [0, 1].each do |index|
    battler = battle.battlers[index]
    types = [battler.type1, battler.type2]
    log.puts "Species #{battler.species}: #{types.inspect}"
    (0..PBTypes.maxValue).each do |attack_type|
      next if PBTypes.isPseudoType?(attack_type)
      effectiveness = PBTypes.getCombinedEffectiveness(attack_type, *types)
      raise 'Invalid effectiveness at battle entry' unless effectiveness.is_a?(Numeric)
    end
  end
  raise 'Single-type species gained a second type' unless eevee.type1 == eevee.type2
  saved = Marshal.load(Marshal.dump($PokemonGlobal))
  before = saved.random_types[PBSpecies::BIDOOF].dup
  $PokemonGlobal = saved
  raise 'Reload changed Bidoof types' unless [bidoof.type1, bidoof.type2] == before
  $PokemonGlobal.random_types[PBSpecies::BIDOOF] = [nil, nil]
  battle.battlers[1].pbInitPokemon(bidoof, 0)
  repaired = [battle.battlers[1].type1, battle.battlers[1].type2]
  raise 'Old-save repair failed' unless repaired.all? { |type| type.is_a?(Integer) }
  PBTypes.getCombinedEffectiveness(PBTypes::NORMAL, *repaired)
  log.puts 'PASS real starter/Bidoof battler initialization, every attack type, save reload and old-save repair'
  log.puts 'RESULT PASS'
rescue Exception => error
  log.puts "RESULT FAIL: #{error.class}: #{error.message}"
  log.puts error.backtrace
ensure
  log.close
  exit!
end
'@
# Ruby 1.8 on Windows resolves filesystem strings with the system code page.
$ruby = $ruby.Replace('__FIXTURE__', $fixture.Replace('\','/')).Replace('__GAME__', $game.Replace('\','/')).Replace('__REPO__', $repo.Replace('\','/')).Replace('__UNPATCHED__', $(if ($Unpatched) {'1'} else {'0'}))
[IO.File]::WriteAllText("$fixture/test.rb", $ruby, [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage))
$process = Start-Process -FilePath "$fixture/Game.exe" -WorkingDirectory $fixture -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(30000)) {
    Stop-Process -Id $process.Id -Force
    throw "Type integration timed out; inspect $fixture"
}
$result = [IO.File]::ReadAllText("$fixture/result.txt")
Write-Output $result
if (-not $result.Contains('RESULT PASS')) { throw "Type integration failed; inspect $fixture" }
$resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
$resolvedTemp = (Resolve-Path -LiteralPath $env:TEMP).Path.TrimEnd('\')
if (-not $resolvedFixture.StartsWith($resolvedTemp + '\', [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $resolvedFixture) -notlike 'pzn-type-integration-*') {
    throw "Unsafe test cleanup path: $resolvedFixture"
}
Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
