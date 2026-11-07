# encoding: UTF-8
# Loaded by boss_moves_integration.ps1 after the actual game's definitions.
def check_boss(value, message); raise message unless value; end
def move_ids(pokemon); pokemon.moves.collect { |move| move.id }; end
def expected_boss_moves(pokemon)
  copy = Marshal.load(Marshal.dump(pokemon))
  copy.resetMoves
  move_ids(copy)
end
class PokeBattle_Battle
  # Stop at native battler initialization; no graphics, Main or save writes.
  alias_method :pzn_boss_test_real_core, :pbStartBattleCore
  def pbStartBattleCore(canlose)
    @battlers[1].pbInitPokemon(@party2[0],0)
    :entered
  end
end
2.times { PZHardcoreNuzlocke.install_random_move_hooks }
if ENV['PZN_BOSS_UNPATCHED'] == '1' && PokeBattle_Battle.method_defined?(:pzn_random_original_battle_core)
  PokeBattle_Battle.class_eval { alias_method :pbStartBattleCore, :pzn_random_original_battle_core }
end
$game_temp = Game_Temp.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_map = Struct.new(:map_id).new(1)
$PokemonGlobal = PokemonGlobalMetadata.new
$Trainer = PokeBattle_Trainer.new('Boss test',0)
player = PokeBattle_Pokemon.new(PBSpecies::BULBASAUR,16,$Trainer)
$Trainer.party = [player]
config = {:enabled=>true,:moves=>true,:semi_random=>false,:progressive=>true,
  :generations=>[1,2,3,4,5,6,7,8,9],:ability_mode=>:NO_RANDOM,
  :evolutions=>false,:evo_similar_bst=>false,:tm_compat=>false,
  :types=>false,:items=>false,:event_items=>false,:held_items=>false,:trainer_rewards=>false}
PZHardcoreNuzlocke.test_config = config
check_boss(PZHardcoreNuzlocke.apply_random_config!, 'Random configuration failed')
# Select actual early/late leaders with fixed sets from this edition's data.
data = load_data('Data/trainers.dat')
types = [:LIDER1,:LIDER4,:LIDER8].collect { |name| getID(PBTrainers,name) }
records = types.collect do |id|
  data.find { |record| record[0] == id && record[3].any? { |poke| poke[TPMOVE1].to_i > 0 } }
end.compact
check_boss(records.length >= 2, 'Insufficient real boss records')
records.each do |record|
  loaded = pbLoadTrainer(record[0],record[1],record[4])
  check_boss(loaded && loaded[2].length > 0, 'Real boss did not load')
  before = loaded[2].collect { |pokemon| move_ids(pokemon) }
  expected = loaded[2].collect { |pokemon| expected_boss_moves(pokemon) }
  puts "Boss #{record[1]} party=#{record[4]} preset=#{before.inspect} expected=#{expected.inspect}"
  battle = PokeBattle_Battle.new(Object.new,[player],loaded[2],$Trainer,loaded[0])
  player_before = Marshal.dump(player.moves)
  check_boss(battle.pbStartBattleCore(false) == :entered, 'Battle return changed')
  actual = battle.party2.collect { |pokemon| move_ids(pokemon) }
  check_boss(actual == expected, "Boss #{record[1]} kept preset moves despite Random moves ON")
  check_boss(Marshal.dump(player.moves) == player_before, 'Player moves changed')
  check_boss(battle.battlers[1].moves.collect { |move| move.id } == expected[0], 'Battler did not receive randomized moves')
end
puts 'PASS real early/late leader loaders and native battler move copying'

# A scripted wild boss overwrites four moves after Pokemon construction.
$PokemonGlobal.pause_random_species = true
$game_switches[482] = true
wild = PokeBattle_Pokemon.new(PBSpecies::FURFROU,16)
Events.onWildPokemonCreate.trigger(nil,wild)
scripted = [:TACKLE,:BITE,:TAILWHIP,:GROWL].collect { |name| getID(PBMoves,name) }
check_boss(move_ids(wild) == scripted, 'Real scripted encounter override not exercised')
expected = expected_boss_moves(wild)
battle = PokeBattle_Battle.new(Object.new,[player],[wild],$Trainer,nil)
battle.pbStartBattleCore(false)
check_boss(move_ids(wild) == expected, 'Scripted wild boss kept preset moves')
check_boss(wild.status == PBStatuses::CADUCO, 'Scripted encounter status lost')
check_boss(wild.species == PBSpecies::FURFROU, 'Scripted species changed at battle boundary')
$game_switches[482] = false
puts 'PASS real scripted encounter override; species and status preserved'

# Moves OFF, Semi Random and a normal game must retain trainer presets.
record = records[0]
[[true,false,false],[true,true,true],[false,false,true]].each do |enabled,semi,moves|
  config[:enabled],config[:semi_random],config[:moves] = enabled,semi,moves
  $game_switches[409] = enabled
  $PokemonGlobal.semi_random = semi
  $PokemonGlobal.enable_random_moves = moves
  trainer = pbLoadTrainer(record[0],record[1],record[4])
  before = trainer[2].collect { |pokemon| Marshal.dump(pokemon.moves) }
  battle = PokeBattle_Battle.new(Object.new,[player],trainer[2],$Trainer,trainer[0])
  battle.pbStartBattleCore(false)
  check_boss(battle.party2.collect { |pokemon| Marshal.dump(pokemon.moves) } == before, 'Disabled/Semi Random presets changed')
  if semi || !enabled
    check_boss(trainer[2].collect { |pokemon| pokemon.species } == record[3].collect { |poke| poke[TPSPECIES] }, 'Semi Random or normal trainer species changed')
  end
end
puts 'PASS moves OFF, Semi Random and normal-game trainer teams'

config[:enabled],config[:semi_random],config[:moves] = true,false,true
$PokemonGlobal.semi_random = false
$PokemonGlobal.enable_random_moves = true
$game_switches[409] = true
opponent = PokeBattle_Trainer.new('Fixed battle',0)
foe = PokeBattle_Pokemon.new(PBSpecies::EEVEE,16,opponent)
expected = expected_boss_moves(foe)
foe.pbDeleteAllMoves
scripted.each { |move| foe.pbLearnMove(move) }
battle = PokeBattle_Battle.new(Object.new,[player],[foe],$Trainer,opponent)
# Some events temporarily disable Random around a story battle.
$game_switches[409] = false
before = $game_switches[409]
battle.pbStartBattleCore(false)
check_boss(move_ids(foe) == expected, 'Story pause suppressed configured random moves')
check_boss($game_switches[409] == before, 'Story Random pause not restored')
foe.moves[0].pp = 1
battle.pbStartBattleCore(false)
check_boss(foe.moves[0].pp == 1, 'Repeated battle preparation reset PP')
$game_switches[409] = true
puts 'PASS temporary story pause and one preparation per battle'

# The game shallow-clones the player for a mirror boss, sharing its move array.
mirror = player.clone
check_boss(mirror.moves.equal?(player.moves), 'Mirror fixture does not share moves')
player_before = Marshal.dump(player.moves)
battle = PokeBattle_Battle.new(Object.new,[player],[mirror],$Trainer,opponent)
battle.pbStartBattleCore(false)
check_boss(Marshal.dump(player.moves) == player_before, 'Mirror boss altered player moves')
check_boss(!mirror.moves.equal?(player.moves), 'Mirror boss still shares player move array')
battle = PokeBattle_Battle.new(Object.new,$Trainer.party,$Trainer.party,$Trainer,opponent)
battle.pbStartBattleCore(false)
check_boss(Marshal.dump(player.moves) == player_before, 'Shared enemy/player party altered player moves')
check_boss(!battle.party2.equal?(battle.party1) && !battle.party2[0].equal?(player), 'Shared enemy party was not detached')
puts 'PASS mirror and shared-party protection for player learned moves'

# Both enemy trainers are prepared in a double battle; a partner on our side
# keeps its learned moves and PP just like the player's own Pokemon.
ally = PokeBattle_Pokemon.new(PBSpecies::PIKACHU,16,$Trainer)
foes = [PBSpecies::EEVEE,PBSpecies::BIDOOF].collect { |species| PokeBattle_Pokemon.new(species,16,opponent) }
expected = foes.collect { |pokemon| expected_boss_moves(pokemon) }
foes.each { |pokemon| pokemon.pbDeleteAllMoves; scripted.each { |move| pokemon.pbLearnMove(move) } }
allies_before = Marshal.dump([player.moves,ally.moves])
battle = PokeBattle_Battle.new(Object.new,[player,ally],foes,[$Trainer,$Trainer],[opponent,opponent])
battle.pbStartBattleCore(false)
check_boss(battle.party2.collect { |pokemon| move_ids(pokemon) } == expected, 'Double battle enemy moves not prepared')
check_boss(Marshal.dump([player.moves,ally.moves]) == allies_before, 'Player or partner moves changed')
puts 'PASS both opponents in double battles and unchanged partner moves'

# A failed move lookup restores all previously prepared party members and the
# story pause. No partial modification or permanent Random flag change remains.
foes.each { |pokemon| pokemon.pbDeleteAllMoves; scripted.each { |move| pokemon.pbLearnMove(move) } }
before = foes.collect { |pokemon| Marshal.dump(pokemon.moves) }
class << foes[1]
  def resetMoves; super; raise 'Injected boss move failure'; end
end
battle = PokeBattle_Battle.new(Object.new,[player],foes,$Trainer,opponent)
$game_switches[409] = false
check_boss(!PZHardcoreNuzlocke.prepare_random_opponent_moves(battle), 'Move lookup error hidden')
check_boss(foes.collect { |pokemon| Marshal.dump(pokemon.moves) } == before, 'Partial preparation not rolled back')
check_boss(!$game_switches[409] && $PokemonGlobal.enable_random_moves && !$PokemonGlobal.semi_random, 'Move lookup error leaked Random flags')
check_boss(!battle.instance_variable_get(:@pzn_random_moves_prepared), 'Failure prevented retry')
class << foes[1]; remove_method :resetMoves; end
battle.pbStartBattleCore(false)
check_boss(battle.instance_variable_get(:@pzn_random_moves_prepared), 'Retry after failed lookup did not prepare moves')
$game_switches[409] = true
puts 'PASS partial-lookup rollback, flag restoration and retry after error'

# Check the game's special boss entry point independently of rendering.
# Its original Random wrapper omits the full-Random branch entirely.
Object.class_eval do
  alias_method :pzn_boss_test_native_entry, :pbBossFightRandom
  def pbBossFightRandom(*arguments)
    $boss_test_call = [arguments, $game_switches[409]]
    raise 'Injected boss entry failure' if $boss_test_error
    $boss_test_result
  end
end
arguments = [PBSpecies::FURFROU,16,0,81,false,true]
[[false,false],[true,false],[true,true]].each do |enabled,semi|
  config[:enabled],config[:semi_random] = enabled,semi
  $PokemonGlobal.semi_random = semi
  $game_switches[409] = enabled
  [false,true].each do |result|
    $boss_test_result = result
    $boss_test_call = nil
    actual = pbBossFight(*arguments)
    check_boss(actual == result, 'Special boss entry lost battle return value')
    check_boss($boss_test_call == [arguments,enabled && !semi], 'Special boss not called with expected Random context')
    check_boss($game_switches[409] == enabled, 'Special boss leaked Random switch')
  end
end
$boss_test_error = true
begin
  pbBossFight(*arguments)
  raise 'Expected boss entry failure'
rescue RuntimeError => error
  check_boss(error.message == 'Injected boss entry failure', 'Wrong boss error')
end
check_boss($game_switches[409], 'Semi Random boss exception left Random paused')
$boss_test_error = false
puts 'PASS special boss entry: full/Semi/normal, wins/losses, arguments and exception restoration'
