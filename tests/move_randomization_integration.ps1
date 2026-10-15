# Runs the real move readers and Pokemon constructors without Main or save files.
[CmdletBinding()]
param(
    [string]$GameFolder = "$PSScriptRoot/../POKEMON Z V2.13/Pokemon Z V2.13",
    [switch]$Unpatched
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$game = (Resolve-Path -LiteralPath $GameFolder).Path
$fixture = Join-Path $env:TEMP ('pzn-move-integration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item -LiteralPath "$game/Game.exe", "$game/Game.ini" -Destination $fixture
Get-ChildItem -LiteralPath $game -Filter '*.dll' | Copy-Item -Destination $fixture
$config = @{rgssVersion=1; gameFolder=$game; customScript="$fixture/test.rb"}
[IO.File]::WriteAllText("$fixture/mkxp.json", ($config | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
$ruby = @'
log = File.open('__FIXTURE__/result.txt', 'wb')
log.sync = true
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
  messages = Messages.new
  messages.instance_variable_set(:@messages, File.open('Data/messages.dat', 'rb') { |file| Marshal.load(file) })
  MessageTypes.send(:class_variable_set, :@@messages, messages)
  raise 'Move names not loaded for generation' if PBMoves.getName(1).to_s.empty?
  module PZHardcoreNuzlocke
    def self.log(message); end
    def self.random_state; @test_config; end
    def self.test_config=(value); @test_config = value; end
  end
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/random.rb'
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/hooks.rb'
  module PZHardcoreNuzlocke
    def self.random_state; @test_config; end
  end
  2.times { PZHardcoreNuzlocke.install_random_starter_hooks }
  unless '__UNPATCHED__' == '1'
    2.times { PZHardcoreNuzlocke.install_random_move_hooks }
  end
  $game_temp = Game_Temp.new
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $PokemonGlobal = PokemonGlobalMetadata.new
  $Trainer = PokeBattle_Trainer.new('Moves test', 0)
  level = 16
  species = PBSpecies::BULBASAUR
  normal = PokeBattle_Pokemon.new(species, level, $Trainer)
  expected_list = normal.getMoveList
  expected_moves = normal.moves.collect { |move| move.id }
  log.puts "Normal moves: #{expected_moves.inspect}"
  config = {:moves=>false, :semi_random=>false, :progressive=>true,
    :generations=>[1,2,3,4,5,6,7,8,9], :ability_mode=>:NO_RANDOM,
    :evolutions=>false, :evo_similar_bst=>false, :tm_compat=>false,
    :types=>false, :items=>false, :held_items=>false, :trainer_rewards=>false}
  PZHardcoreNuzlocke.test_config = config
  raise 'Random setup failed' unless PZHardcoreNuzlocke.apply_random_config!
  $PokemonGlobal.pause_random_species = true
  [false, true].each do |legacy|
    $game_switches[802] = legacy
    pokemon = PokeBattle_Pokemon.new(species, level, $Trainer)
    actual = pokemon.moves.collect { |move| move.id }
    log.puts "Random moves OFF, legacy=#{legacy}: #{actual.inspect}"
    raise 'Disabled moves option still randomizes moves' unless actual == expected_moves
    raise 'Disabled moves option still randomizes learnset' unless pokemon.getMoveList == expected_list
    raise 'Move lookup leaked switch changes' unless $game_switches[409] && $game_switches[802] == legacy
  end
  $game_switches[802] = false
  # Real starter delivery, without opening the gift/nickname UI.
  Object.class_eval do
    def pbAddPokemon(species, level, *rest)
      $test_starter = PokeBattle_Pokemon.new(species, level, $Trainer)
      true
    end
  end
  $game_variables[RandomizedChallenge::STATERS_VARIABLES[0]] = species
  give_starter_random(0, nil, level)
  raise 'Starter ignores disabled moves option' unless $test_starter.moves.collect { |move| move.id } == expected_moves
  # Same construction/reset path used by trainers and the move relearner.
  opponent = PokeBattle_Trainer.new('Opponent', 0)
  trainer_pokemon = PokeBattle_Pokemon.new(species, level, opponent)
  trainer_pokemon.resetMoves
  raise 'Trainer Pokemon moves randomized while disabled' unless trainer_pokemon.moves.collect { |move| move.id } == expected_moves
  log.puts 'PASS original starter and trainer moves'
  config[:semi_random] = true
  config[:moves] = true
  raise 'Semi Random setup failed' unless PZHardcoreNuzlocke.apply_random_config!
  $PokemonGlobal.pause_random_species = true
  semi = PokeBattle_Pokemon.new(species, level, $Trainer)
  raise 'Semi Random randomizes moves' unless semi.getMoveList == expected_list
  log.puts 'PASS Semi Random moves'
  config[:semi_random] = false
  config[:moves] = true
  raise 'Enabled moves setup failed' unless PZHardcoreNuzlocke.apply_random_config!
  $PokemonGlobal.pause_random_species = true
  log.puts 'Checking enabled move randomization'
  enabled = PokeBattle_Pokemon.new(species, level, $Trainer)
  randomized = enabled.getMoveList
  raise 'Enabled move randomization stopped working' if randomized == expected_list
  raise 'Random moves not cached' unless $PokemonGlobal.random_moves[species]
  $game_variables[RandomizedChallenge::STATERS_VARIABLES[0]] = species
  give_starter_random(0, nil, level)
  raise 'Enabled starter randomization changed species' unless $test_starter.species == species
  raise 'Enabled starter randomization lost cached learnset' unless $test_starter.getMoveList == randomized
  # Disabling the option must bypass, rather than delete, an existing cache.
  $PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
  cached = Marshal.dump($PokemonGlobal.random_moves)
  learned = enabled.moves.collect { |move| move.id }
  $PokemonGlobal.enable_random_moves = false
  raise 'Old cache overrides disabled option' unless enabled.getMoveList == expected_list
  raise 'Disabled lookup changed cached random moves' unless Marshal.dump($PokemonGlobal.random_moves) == cached
  raise 'Existing learned moves overwritten' unless enabled.moves.collect { |move| move.id } == learned
  raise 'Move lookup turned off Random' unless $game_switches[409]
  log.puts 'PASS moves off/on, both legacy switches, starter, trainer construction, Semi Random, cached saves and switch restoration'
  log.puts 'RESULT PASS'
rescue Exception => error
  log.puts "RESULT FAIL: #{error.class}: #{error.message}"
  log.puts error.backtrace
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
    throw "Move integration timed out; inspect $fixture"
}
$result = [IO.File]::ReadAllText("$fixture/result.txt")
Write-Output $result
if (-not $result.Contains('RESULT PASS')) { throw "Move integration failed; inspect $fixture" }
$resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
$resolvedTemp = (Resolve-Path -LiteralPath $env:TEMP).Path.TrimEnd('\')
if (-not $resolvedFixture.StartsWith($resolvedTemp + '\', [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $resolvedFixture) -notlike 'pzn-move-integration-*') {
    throw "Unsafe test cleanup path: $resolvedFixture"
}
Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
