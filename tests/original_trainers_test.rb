# encoding: UTF-8
# Loaded by original_trainers_integration.ps1 in the real game's Ruby runtime.
def check_original(value, message); raise message unless value; end
def original_team_snapshot(party)
  party.collect do |pokemon|
    [pokemon.species, pokemon.form, pokemon.level, pokemon.item,
     pokemon.moves.collect { |move| [move.id, move.pp] }, pokemon.ability,
     pokemon.type1, pokemon.type2, pokemon.iv.dup, pokemon.ev.dup]
  end
end

class PokeBattle_Battle
  # Exercise native battler copying without starting the graphical battle loop.
  def pbStartBattleCore(canlose)
    @battlers[0].pbInitPokemon(@party1[0], 0)
    @battlers[1].pbInitPokemon(@party2[0], 0)
    :entered
  end
  def pbDisplay(*arguments); end
  def pbCommonAnimation(*arguments); end
  def pbGetMegaRingName(*arguments); 'Test ring'; end
end
class OriginalTrainerTestScene
  def pbChangePokemon(*arguments); end
end
module PBDebug
  def self.log(*arguments); end
end
2.times do
  PZHardcoreNuzlocke.install_random_ability_hooks
  PZHardcoreNuzlocke.install_random_type_hooks
  PZHardcoreNuzlocke.install_random_move_hooks
  PZHardcoreNuzlocke.install_random_starter_hooks
  PZHardcoreNuzlocke.install_random_trainer_hooks
  PZHardcoreNuzlocke.install_item_randomization_hooks
end
$game_temp = Game_Temp.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$game_map = Struct.new(:map_id).new(1)
$PokemonGlobal = PokemonGlobalMetadata.new
$Trainer = PokeBattle_Trainer.new('Original teams test', 0)
$PokemonBag = PokemonBag.new
$ItemData = readItemList('Data/items.dat')
config = PZHardcoreNuzlocke.default_random_state
check_original(config[:original_trainers] == false, 'New option must default to OFF')
config[:original_trainers] = true
config[:event_items] = true
config[:types] = true
PZHardcoreNuzlocke.test_config = config
data = load_data('Data/trainers.dat')
records = [:LIDER1, :LIDER4, :LIDER8].collect do |type|
  data.find { |record| record[0] == getID(PBTrainers, type) && record[3].any? { |poke| poke[TPMOVE1].to_i > 0 } }
end.compact
check_original(records.length >= 2, 'Missing real leader teams')
player = nil

# Use the normal loader as the reference, including all three difficulties.
[0, 698, 666].each do |difficulty|
  $game_switches[698] = difficulty == 698
  $game_switches[666] = difficulty == 666
  records.each do |record|
    $game_switches[409] = $game_switches[802] = false
    baseline = original_team_snapshot(pbLoadTrainer(record[0], record[1], record[4])[2])
    check_original(PZHardcoreNuzlocke.apply_random_config!, 'Random setup failed')
    $game_switches[802] = true # EN/FR's independent legacy move reader.
    trainer = pbLoadTrainer(record[0], record[1], record[4])
    check_original(original_team_snapshot(trainer[2]) == baseline, 'Original trainer data changed')
    check_original($game_switches[409] && $game_switches[802], 'Loader leaked Random switches')
    player = PZHardcoreNuzlocke.with_original_trainer_data do
      PokeBattle_Pokemon.new(trainer[2][0].species, trainer[2][0].level, $Trainer)
    end
    $Trainer.party = [player]
    # Both sides use the same species, but the player's tables must not leak.
    species = player.species
    replacement = baseline[0][5] == PBAbilities::SPEEDBOOST ? PBAbilities::INTIMIDATE : PBAbilities::SPEEDBOOST
    $PokemonGlobal.random_abs_pokemon = {species=>{0=>[[replacement,0],[replacement,1],[replacement,2]]}}
    $PokemonGlobal.random_types = {species=>[PBTypes::FAIRY, PBTypes::FAIRY]}
    $PokemonGlobal.random_abs_pokes = {trainer[2][0].id=>[[replacement,0]]}
    # Clear the legacy cache for the player only by assigning an independent ID.
    player.id = 'player'
    check_original(player.ability == replacement, 'Player lost Full Random abilities')
    check_original(player.type1 == PBTypes::FAIRY, 'Player lost Random types')
    check_original(player.getMoveList != PZHardcoreNuzlocke.with_original_trainer_data { player.getMoveList }, 'Player lost Random moves')
    caches = Marshal.dump([$PokemonGlobal.random_abs_pokemon, $PokemonGlobal.random_types,
      $PokemonGlobal.random_abs_pokes, $PokemonGlobal.random_moves])
    check_original(original_team_snapshot(trainer[2]) == baseline, 'Player tables changed trainer abilities or types')
    battle = PokeBattle_Battle.new(OriginalTrainerTestScene.new, [player], trainer[2], $Trainer, trainer[0])
    check_original(battle.pbStartBattleCore(false) == :entered, 'Battle return changed')
    check_original(battle.battlers[0].ability == replacement, 'Player battler lost Random ability')
    check_original(battle.battlers[1].ability == baseline[0][5], 'Opponent battler copied Random ability')
    check_original(original_team_snapshot(trainer[2]) == baseline, 'Trainer presets overwritten at battle start')
    check_original(Marshal.dump([$PokemonGlobal.random_abs_pokemon, $PokemonGlobal.random_types,
      $PokemonGlobal.random_abs_pokes, $PokemonGlobal.random_moves]) == caches, 'Trainer lookup changed saved player tables')
  end
end
puts 'PASS real early/late leaders, all difficulties, same-species player/foe isolation and legacy switches'

# Native Mega Evolution queries the Pokemon again after changing form.
$game_switches[698] = $game_switches[666] = false
$game_switches[802] = false
[:FULL_RANDOM_ABS, :MAP_RANDOM_ABS].each do |mode|
  config[:ability_mode] = mode
  check_original(PZHardcoreNuzlocke.apply_random_config!, 'Mega setup failed')
  player = PZHardcoreNuzlocke.with_original_trainer_data { PokeBattle_Pokemon.new(PBSpecies::LOPUNNY, 50, $Trainer) }
  player.setItem(PBItems::LOPUNNYTE)
  player.setAbility(0)
  enemy = Marshal.load(Marshal.dump(player))
  $PokemonGlobal.random_abs_pokemon = {PBSpecies::LOPUNNY=>{0=>[[PBAbilities::INTIMIDATE,0]],1=>[[PBAbilities::SPEEDBOOST,0]]}}
  $PokemonGlobal.ability_hash = {PBAbilities::SCRAPPY=>PBAbilities::SPEEDBOOST}
  opponent = PokeBattle_Trainer.new('Mega foe', 0)
  battle = PokeBattle_Battle.new(OriginalTrainerTestScene.new, [player], [enemy], $Trainer, opponent)
  battle.pbStartBattleCore(false)
  [0,1].each { |index| battle.pbMegaEvolve(index) }
  check_original(player.isMega? && enemy.isMega?, 'Native Mega Evolution did not execute')
  check_original(battle.battlers[0].ability == PBAbilities::SPEEDBOOST, 'Player Mega lost random ability')
  check_original(battle.battlers[1].ability == PBAbilities::SCRAPPY, 'Trainer Mega lost canonical ability')
  enemy.makeUnmega
  normal = PZHardcoreNuzlocke.with_original_trainer_data { enemy.ability }
  check_original(enemy.ability == normal, 'Trainer unmega lost canonical ability')
  enemy = Marshal.load(Marshal.dump(enemy))
  enemy.makeMega
  check_original(enemy.ability == PBAbilities::SCRAPPY, 'Saved trainer marker lost on reload')
end
puts 'PASS Full Random/mapped native Megas, effective battler abilities, unmega and reload'

# Double battles and mirrored teams must not mark the player's own objects.
player.makeUnmega
trainer1 = pbLoadTrainer(records[0][0], records[0][1], records[0][4])
trainer2 = pbLoadTrainer(records[-1][0], records[-1][1], records[-1][4])
party = trainer1[2] + trainer2[2]
before = original_team_snapshot(party)
battle = PokeBattle_Battle.new(OriginalTrainerTestScene.new, [player], party, $Trainer, [trainer1[0], trainer2[0]])
battle.pbStartBattleCore(false)
check_original(original_team_snapshot(party) == before, 'Double battle changed opponent presets')
before = Marshal.dump(player)
shared = [player]
battle = PokeBattle_Battle.new(OriginalTrainerTestScene.new, shared, shared, $Trainer, trainer1[0])
battle.pbStartBattleCore(false)
check_original(!battle.party2.equal?(battle.party1) && !battle.party2[0].equal?(player), 'Mirror did not detach shared objects')
check_original(Marshal.dump(player) == before, 'Mirror changed the player Pokemon')
puts 'PASS double trainers and shared-party mirror isolation'

# Starter/gift delivery, wild encounters, items and TMs keep the normal Random
# paths. Suppress only gift UI while still using the real Pokemon constructor.
Object.class_eval do
  def pbAddPokemon(species, level, *rest)
    $original_test_gift = PokeBattle_Pokemon.new(species, level, $Trainer)
    true
  end
end
config[:ability_mode] = :FULL_RANDOM_ABS
check_original(PZHardcoreNuzlocke.apply_random_config!, 'Player acquisition setup failed')
species = PBSpecies::BULBASAUR
3.times do |index|
  $game_variables[RandomizedChallenge::STATERS_VARIABLES[index]] = species
  give_starter_random(index, nil, 16)
  check_original($original_test_gift.species == species, 'Selected starter rerolled')
  check_original(!$original_test_gift.instance_variable_get(:@pzn_original_trainer), 'Starter marked as trainer Pokemon')
  check_original($original_test_gift.getMoveList == $PokemonGlobal.random_moves[species][0], 'Starter lost Random learnset')
end
$PokemonGlobal.pause_random_species = true
wild = PokeBattle_Pokemon.new(species, 16)
gift = PokeBattle_Pokemon.new(species, 16, $Trainer)
check_original(wild.getMoveList == gift.getMoveList && !$PokemonGlobal.random_moves[species][0].empty?, 'Wild/gift learnsets not random')
check_original(PZHardcoreNuzlocke.event_items_randomized? && random_items_enabled? && random_tm_compat_on?, 'Player items or TMs disabled')
# Wild scripted bosses still receive random moves, even with original trainers.
wild.pbDeleteAllMoves
[:TACKLE,:GROWL].each { |move| wild.pbLearnMove(move) }
battle = PokeBattle_Battle.new(OriginalTrainerTestScene.new, [gift], [wild], $Trainer, nil)
check_original(PZHardcoreNuzlocke.prepare_random_opponent_moves(battle), 'Wild boss random moves incorrectly disabled')
# Force a different generation so species checks cannot pass by coincidence.
$PokemonGlobal.random_gens = [1]
$PokemonGlobal.pause_random_species = false
wild = PokeBattle_Pokemon.new(PBSpecies::LUCARIO, 16)
pbAddPokemon(PBSpecies::LUCARIO, 16)
check_original(wild.species.between?(1,151) && $original_test_gift.species.between?(1,151), 'Wild or event gift species did not randomize')
gift.isCompatibleWithMove?(PBMoves::TACKLE)
check_original($PokemonGlobal.tm_compatibility_random[gift.species].any? { |entry| entry[0] == PBMoves::TACKLE }, 'Player TM compatibility did not randomize')
class << Kernel
  def pbMessage(*arguments); end
end
module PZHardcoreNuzlocke
  def self.current_item_event; Struct.new(:character_name).new('objetoMT'); end
end
tms = PZHardcoreNuzlocke.all_random_tms
missing = tms[-1]
[:pbItemBall, :pbReceiveItem].each do |path|
  $PokemonBag = PokemonBag.new
  tms[0...-1].each { |item| $PokemonBag.pbStoreItem(item) }
  check_original(Kernel.send(path, :TM01), 'TM delivery failed')
  check_original($PokemonBag.pbHasItem?(missing), 'Map/event TM was not randomized')
  move = $PokemonGlobal.tm_moves[missing]
  check_original(move && $ItemData[missing][ITEMMACHINE] == move, 'TM move did not randomize or persist')
end
puts 'PASS three starters, wild/event gift species, TM compatibility, map/event TM rewards and wild bosses'

# A failed loader/lookup must restore flags and the same legacy cache object.
old_flags = [$game_switches[409], $game_switches[802]]
cache = $PokemonGlobal.random_abs_pokes = {'sentinel'=>[[1,0]]}
begin
  PZHardcoreNuzlocke.with_original_trainer_data do
    PZHardcoreNuzlocke.with_original_trainer_data { raise 'Injected trainer failure' }
  end
rescue RuntimeError => error
  check_original(error.message == 'Injected trainer failure', 'Wrong failure')
end
check_original([$game_switches[409], $game_switches[802]] == old_flags && $PokemonGlobal.random_abs_pokes.equal?(cache), 'Exception leaked lookup state')
$game_switches[409] = false
pbLoadTrainer(records[0][0], records[0][1], records[0][4])
check_original(!$game_switches[409], 'Trainer load resumed a story pause')
$game_switches[409] = true
config[:original_trainers] = false
trainer = pbLoadTrainer(records[0][0], records[0][1], records[0][4])
check_original(!trainer[2][0].instance_variable_get(:@pzn_original_trainer), 'OFF mode marked trainer Pokemon')
config[:semi_random] = true
$PokemonGlobal.semi_random = true
canonical = PZHardcoreNuzlocke.with_original_trainer_data { gift.getMoveList }
check_original(gift.getMoveList == canonical && !random_items_enabled?, 'Existing Semi Random behavior changed')
puts 'PASS nesting, exception restoration, story pauses, OFF mode and existing Semi Random'

# Old configurations acquire a false default without unlocking their choices.
legacy = PZHardcoreNuzlocke.default_state
legacy[:random].delete(:original_trainers)
legacy[:random][:locked] = true
PZHardcoreNuzlocke.migrate_state!(legacy)
check_original(legacy[:random][:original_trainers] == false && legacy[:random][:locked], 'Migration changed existing run')
[:es,:en,:fr].each do |language|
  [:random_original_trainers, :random_original_trainers_help].each do |key|
    check_original(PZHardcoreNuzlocke::I18n.lookup(language,key) != key.to_s, 'Missing option translation')
  end
end
check_original(PZHardcoreNuzlocke::RANDOM_RULES.any? { |entry| entry[0] == :original_trainers }, 'New option not exposed in setup')
check_original(PZHardcoreNuzlocke.random_boolean_commands.any? { |command| command.include?(PZHardcoreNuzlocke.t(:random_original_trainers)) }, 'New option missing from actual menu')
puts 'PASS save migration, locked settings and ES/EN/FR option text'
