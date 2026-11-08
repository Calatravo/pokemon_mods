# encoding: UTF-8
# Run via mega_abilities_integration.ps1 in the game's own Ruby runtime.
def check_mega(value, message); raise message unless value; end
class PokeBattle_Battle
  def pbDisplay(*arguments); end
  def pbCommonAnimation(*arguments); end
  def pbGetMegaRingName(*arguments); 'Test ring'; end
end
class MegaAbilityTestScene
  def pbChangePokemon(*arguments); end
end
module PBDebug
  def self.log(*arguments); end
end
PokeBattle_Pokemon.class_eval do
  alias_method :pzn_mega_test_original_ability, :ability
  alias_method :pzn_mega_test_original_list, :getAbilityList
end
2.times { PZHardcoreNuzlocke.install_random_ability_hooks }
if ENV['PZN_MEGA_UNPATCHED'] == '1'
  PokeBattle_Pokemon.class_eval do
    alias_method :ability, :pzn_mega_test_original_ability
    alias_method :getAbilityList, :pzn_mega_test_original_list
  end
end
$game_temp = Game_Temp.new
$game_switches = Game_Switches.new
$game_variables = Game_Variables.new
$PokemonGlobal = PokemonGlobalMetadata.new
$Trainer = PokeBattle_Trainer.new('Mega test',0)
config = {:moves=>false,:semi_random=>false,:progressive=>true,
  :generations=>[1,2,3,4,5,6,7,8,9],:ability_mode=>:FULL_RANDOM_ABS,
  :evolutions=>false,:evo_similar_bst=>false,:tm_compat=>false,
  :types=>false,:items=>false,:held_items=>false,:trainer_rewards=>false}
PZHardcoreNuzlocke.test_config=config
check_mega(PZHardcoreNuzlocke.apply_random_config!, 'Random setup failed')
$PokemonGlobal.pause_random_species=true
lopunny=PokeBattle_Pokemon.new(PBSpecies::LOPUNNY,50,$Trainer)
lopunny.setItem(PBItems::LOPUNNYTE)
lopunny.setAbility(0)
$PokemonGlobal.random_abs_pokemon ||= {}
$PokemonGlobal.random_abs_pokemon[PBSpecies::LOPUNNY]={
  0=>[[PBAbilities::INTIMIDATE,0]],1=>[[PBAbilities::SPEEDBOOST,0]]}
base=lopunny.ability
opponent=PokeBattle_Trainer.new('Mega opponent',0)
enemy=Marshal.load(Marshal.dump(lopunny))
battle=PokeBattle_Battle.new(MegaAbilityTestScene.new,[lopunny],[enemy],$Trainer,opponent)
battle.battlers[0].pbInitPokemon(lopunny,0)
battle.battlers[1].pbInitPokemon(enemy,0)
[0,1].each do |index|
  battle.pbMegaEvolve(index)
  pokemon=battle.battlers[index].pokemon
  check_mega(pokemon.isMega?, 'Native Mega Evolution did not execute')
  check_mega(pokemon.ability==PBAbilities::SPEEDBOOST, 'Mega Lopunny bypassed saved random form ability')
  check_mega(pokemon.getAbilityList==[[PBAbilities::SPEEDBOOST,0]], 'Mega ability list and actual ability disagree')
  check_mega(battle.battlers[index].ability==PBAbilities::SPEEDBOOST, 'Battle kept canonical Mega ability')
  [0,1,2].each do |slot|
    pokemon.setAbility(slot)
    check_mega(pokemon.ability==PBAbilities::SPEEDBOOST, 'Mega failed normal/secondary/hidden slot fallback')
  end
  pokemon.setAbility(0)
end
lopunny.makeUnmega
battle.battlers[0].pbUpdate(true)
check_mega(lopunny.ability==base && battle.battlers[0].ability==base, 'Base ability not restored after unmega')
snapshot=Marshal.dump($PokemonGlobal.random_abs_pokemon)
$PokemonGlobal=Marshal.load(Marshal.dump($PokemonGlobal))
lopunny=Marshal.load(Marshal.dump(lopunny))
lopunny.makeMega
check_mega(lopunny.ability==PBAbilities::SPEEDBOOST, 'Reload rerolled Mega ability')
lopunny.makeUnmega
check_mega(lopunny.ability==base, 'Reload changed normal ability')
check_mega(Marshal.dump($PokemonGlobal.random_abs_pokemon)==snapshot, 'Existing random tables changed')
puts 'PASS native Mega Evolution on both sides, effective ability, lists, base return and saved tables'

config[:ability_mode]=:MAP_RANDOM_ABS
check_mega(PZHardcoreNuzlocke.apply_random_config!, 'Mapped setup failed')
$PokemonGlobal.pause_random_species=true
$PokemonGlobal.ability_hash={PBAbilities::SCRAPPY=>PBAbilities::INTIMIDATE}
lopunny.makeMega
check_mega(lopunny.ability==PBAbilities::INTIMIDATE, 'Mega Lopunny bypassed consistent mapping')
check_mega(lopunny.getAbilityList==[[PBAbilities::INTIMIDATE,0]], 'Mapped Mega list incorrect')
$PokemonGlobal=Marshal.load(Marshal.dump($PokemonGlobal))
check_mega(lopunny.ability==PBAbilities::INTIMIDATE, 'Mapped Mega ability changed after reload')
$PokemonGlobal.ability_hash=nil
first=lopunny.ability
check_mega($PokemonGlobal.ability_hash[PBAbilities::SCRAPPY]==first && lopunny.ability==first, 'Missing mapping not repaired consistently')
puts 'PASS canonical Mega ability mapping, saved mapping and missing-map repair'

config[:ability_mode]=:FULL_RANDOM_ABS
config[:semi_random]=false
check_mega(PZHardcoreNuzlocke.apply_random_config!, 'Fresh Full Random setup failed')
$PokemonGlobal.pause_random_species=true
[
  [PBSpecies::LOPUNNY,PBItems::LOPUNNYTE],
  [PBSpecies::ABOMASNOW,PBItems::ABOMASNOWITA],
  [PBSpecies::VENUSAUR,PBItems::VENUSAURITE],
  [PBSpecies::CHARIZARD,PBItems::CHARIZARDITEX],
  [PBSpecies::CHARIZARD,PBItems::CHARIZARDITEY]
].each do |species,item|
  pokemon=PokeBattle_Pokemon.new(species,50,$Trainer)
  pokemon.setItem(item)
  pokemon.setAbility(0)
  normal=pokemon.ability
  base_table=Marshal.dump($PokemonGlobal.random_abs_pokemon[species][0])
  pokemon.makeMega
  actual=pokemon.ability
  table=pokemon.getAbilityList
  check_mega(table.any? { |entry| entry[0]==actual }, 'Mega actual ability absent from random list')
  check_mega(actual>0 && actual<=PBAbilities.maxValue && !RandomizedChallenge::ABILITYBLACKLIST.include?(actual), 'Invalid Mega ability')
  check_mega(pokemon.ability==actual, 'Mega ability rerolled between lookups')
  pokemon.makeUnmega
  check_mega(pokemon.ability==normal, 'Normal form ability rerolled')
  check_mega(Marshal.dump($PokemonGlobal.random_abs_pokemon[species][0])==base_table, 'Normal form table modified')
  pokemon.makeMega
  check_mega(pokemon.ability==actual, 'Second Mega Evolution rerolled ability')
  puts "PASS #{PBSpecies.getName(species)} form=#{pokemon.form} ability=#{actual}"
end

# Invalid legacy-form caches are repaired without resetting the normal table.
$PokemonGlobal.random_abs_pokemon[PBSpecies::LOPUNNY][1]=[[nil,0]]
lopunny.makeMega
repaired=lopunny.ability
check_mega(repaired && repaired>0 && lopunny.ability==repaired, 'Invalid Mega cache not repaired')

[:NO_RANDOM,:FULL_RANDOM_ABS].each do |mode|
  config[:ability_mode]=mode
  config[:semi_random]=(mode==:FULL_RANDOM_ABS)
  check_mega(PZHardcoreNuzlocke.apply_random_config!, 'No Random/Semi setup failed')
  check_mega(lopunny.ability==PBAbilities::SCRAPPY, 'No Random/Semi lost canonical Mega ability')
end
$game_switches[409]=false
check_mega(lopunny.ability==PBAbilities::SCRAPPY, 'Normal game lost canonical Mega ability')
puts 'PASS No Random, Semi Random and disabled Random retain canonical Mega abilities'

# Respect the game's optional shared-form table setting, preserving base data.
config[:semi_random]=false
check_mega(PZHardcoreNuzlocke.apply_random_config!, 'Shared forms setup failed')
$PokemonGlobal.random_abs_pokemon={PBSpecies::LOPUNNY=>{0=>[[PBAbilities::INTIMIDATE,0]]}}
previous=RandomizedChallenge::DIFFERENT_FORMS_HAVE_DIFFERENT_ABILITIES
RandomizedChallenge.send(:remove_const,:DIFFERENT_FORMS_HAVE_DIFFERENT_ABILITIES)
RandomizedChallenge.const_set(:DIFFERENT_FORMS_HAVE_DIFFERENT_ABILITIES,false)
begin
  check_mega(lopunny.ability==PBAbilities::INTIMIDATE, 'Shared-form setting did not use base table')
  check_mega(!$PokemonGlobal.random_abs_pokemon[PBSpecies::LOPUNNY].has_key?(1), 'Shared-form setting created a separate Mega table')
ensure
  RandomizedChallenge.send(:remove_const,:DIFFERENT_FORMS_HAVE_DIFFERENT_ABILITIES)
  RandomizedChallenge.const_set(:DIFFERENT_FORMS_HAVE_DIFFERENT_ABILITIES,previous)
end
puts 'PASS shared-form setting and repeated hook installation'
