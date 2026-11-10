# encoding: UTF-8
# Real Pokemon, metadata, maps and hooks; replaces the animated battle endpoint.
def check_story(value, message); raise message unless value; end
StoryEvent = Struct.new(:id)
StoryInterpreter = Struct.new(:event)
class StoryInterpreter
  def get_character(index); event; end
end
StoryMap = Struct.new(:map_id, :interpreter)

def reset_story(map=251, event=1)
  $game_temp = Game_Temp.new
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $PokemonSystem = PokemonSystem.new
  $PokemonGlobal = PokemonGlobalMetadata.new
  $PokemonStorage = PokemonStorage.new
  $game_map = StoryMap.new(map, StoryInterpreter.new(StoryEvent.new(event)))
  $Trainer = PokeBattle_Trainer.new('Story test', 0)
  $Trainer.party = [PokeBattle_Pokemon.new(PBSpecies::ARON, 10, $Trainer)]
  $game_variables[177] = 20
  $story_outcome = :loss
  PZHardcoreNuzlocke.activate!
end

Object.class_eval do
  # Model the native loss endpoint, including the base Nuzlocke heal refusal.
  # Keep the installed public entry so all detection and exemption code runs.
  alias_method :pzn_story_test_native_entry, :pzn_story_original_trainer_battle
  def pzn_story_original_trainer_battle(*arguments)
    $story_arguments = arguments
    return true if $story_outcome == :win
    $Trainer.party.each { |pokemon| pokemon.hp = 0 }
    raise 'expected battle exception' if $story_outcome == :error
    $Trainer.party.each { |pokemon| pokemon.heal } if arguments[5]
    false
  end
end

mod = PZHardcoreNuzlocke
data = load_data('Data/trainers.dat')
ferrofaz = data.find { |record| record[0] == PBTrainers::FERROFAZ && record[4] == 0 }
check_story(ferrofaz && ferrofaz[3].length >= 4, 'Real prison trainer data is missing')
puts "Real prison trainer: #{ferrofaz[3].length} Pokemon"
calls = {}
[[248, 2], [251, 1]].each do |pair|
  page = load_data(sprintf('Data/Map%03d.rxdata',pair[0])).events[pair[1]].pages[0]
  command = page.list.find { |c| c.code == 111 && c.parameters[0] == 12 && c.parameters[1] =~ /pbTrainerBattle/ }
  check_story(command && command.parameters[1] =~ /false,0,true/, 'Real story event does not allow losing')
  calls[pair[0]] = command.parameters[1]
end
reset_story
Object.new.send(:pzn_story_original_trainer_battle, PBTrainers::FERROFAZ, 'test', '', false, 0, true)
check_story(mod.state[:failed] && mod.dead?($Trainer.party[0]), 'Original mental-battle wipe was not reproduced')
puts 'PASS reproduced original mental-battle wipe with native Pokemon death/heal behavior'

[[248, 2], [251, 1]].each do |pair|
  reset_story(pair[0], pair[1])
  pokemon = $Trainer.party[0]
  before = Marshal.dump(mod.state)
  2.times { mod.install_story_battle_hook }
  check_story(eval(calls[pair[0]], TOPLEVEL_BINDING) == false, 'Native defeat result changed')
  check_story($story_arguments[5] == true, 'canlose argument changed')
  check_story(!mod.state[:failed] && mod.state[:deaths].empty?, 'Dream loss counted as death or wipe')
  check_story(!mod.dead?(pokemon) && pokemon.hp == pokemon.totalhp, 'Dream participant was not recovered')
  check_story(Marshal.dump(mod.state) == before && mod.active?, 'Exemption changed saved rules, progress or history')
  $story_outcome = :win
  check_story(eval(calls[pair[0]], TOPLEVEL_BINDING) == true, 'Native win result changed')
end
[[227,1,PBTrainers::FERROFAZ,0,true], [251,2,PBTrainers::FERROFAZ,0,true],
 [251,1,PBTrainers::CINTIA,0,true], [251,1,PBTrainers::FERROFAZ,1,true],
 [251,1,PBTrainers::FERROFAZ,0,false]].each do |map,event,trainer,party,canlose|
  reset_story(map,event)
  pbTrainerBattle(trainer, 'test', '', false, party, canlose, 17, true)
  check_story(mod.state[:failed], 'Unrelated battle received dream exemption')
  check_story($story_arguments[-2,2] == [17,true], 'Trailing native arguments lost')
end
reset_story
$story_outcome = :error
begin
  eval(calls[251], TOPLEVEL_BINDING)
rescue RuntimeError => error
  check_story(error.message.include?('expected battle exception'), "Native exception changed: #{error.message}")
end
check_story(!mod.story_battle_exempt?, 'Exemption leaked after exception')
$Trainer.party[0].healHP
$story_outcome = :loss
$game_map.map_id = 227
pbTrainerBattle(PBTrainers::FERROFAZ, 'test', '', false, 0, true)
check_story(mod.state[:failed], 'Later ordinary defeat did not end run')
puts 'PASS real event calls, both dreams, wins/losses, recovery, boundaries, rest arguments, exception cleanup and ordinary wipes'

def prepare_story_repair(legacy=false)
  reset_story
  mod = PZHardcoreNuzlocke
  earlier = PokeBattle_Pokemon.new(PBSpecies::PIDGEY, 5, $Trainer)
  earlier.nuzlocke_dead = true
  earlier.nuzlocke_death_time = 100
  earlier.hp = 0
  $PokemonStorage[0,0] = earlier
  mod.state[:deaths] << {:name=>earlier.name, :time=>100, :area=>'earlier area', :personal_id=>earlier.personalID}
  mod.state[:zones]['earlier'] = {:status=>:caught}
  mod.state[:random][:enabled] = true
  mod.novice_state[:revives_per_gym] = 2
  mod.novice_state[:revives_used] = 1
  $Trainer.party[0].hp = 0
  check_story(mod.state[:failed], 'Repair fixture has no failed run')
  if legacy
    mod.state[:deaths][-1].delete(:map_id)
    mod.state.delete(:failure_context)
    mod.state.delete(:story_repairs)
    $game_map.map_id = 227 # Already back in prison after the cutscene.
  end
  [$Trainer.party[0], earlier]
end

victim, earlier = prepare_story_repair
current = mod.state
preserved = Marshal.dump([current[:rules], current[:zones], current[:random], current[:novice], current[:started_at]])
check_story(mod.repair_story_wipe!, 'Known false wipe could not be repaired')
check_story(mod.active? && $PokemonGlobal.nuzlocke && !mod.dead?(victim) && victim.hp > 0, 'Repair did not reactivate Nuzlocke or restore target')
check_story(mod.dead?(earlier) && current[:deaths].length == 1 && current[:deaths][0][:time] == 100, 'Repair undid an earlier legitimate death')
check_story(preserved == Marshal.dump([current[:rules],current[:zones],current[:random],current[:novice],current[:started_at]]), 'Repair reset rules, progress, Random or revive budget')
check_story(current[:story_repairs].length == 1 && current[:story_repairs][0][:death][:map_id] == 251, 'False death audit was lost')
check_story(!mod.repair_story_wipe!, 'Repair ran twice')
$PokemonGlobal, $Trainer, $PokemonStorage = Marshal.load(Marshal.dump([$PokemonGlobal, $Trainer, $PokemonStorage]))
check_story(mod.active? && mod.state[:story_repairs].length == 1, 'Save reload lost repair')

victim, earlier = prepare_story_repair(true)
check_story(mod.story_wipe_repair_candidate[:legacy], 'Older save was not recognized')
before = Marshal.dump([$PokemonGlobal,$Trainer,$PokemonStorage])
check_story(!mod.repair_story_wipe!, 'Legacy save repaired without attestation')
check_story(Marshal.dump([$PokemonGlobal,$Trainer,$PokemonStorage]) == before, 'Rejected repair mutated save')
check_story(mod.repair_story_wipe!(true) && mod.active? && mod.dead?(earlier), 'Confirmed old-save repair failed')
puts 'PASS current/legacy saves, explicit attestation, targeted revival, earlier deaths, progress, rules, Random, revive budget, audit and serialization'

victim, earlier = prepare_story_repair
mod.state[:failure_context][:map_id] = 222
mod.state[:deaths][-1][:map_id] = 222
check_story(!mod.story_wipe_repair_candidate && !mod.repair_story_wipe!(true), 'Real prison wipe could be reset')
victim, earlier = prepare_story_repair(true)
mod.state[:deaths][-1][:area] = 'unrelated area'
check_story(!mod.repair_story_wipe!(true), 'Unrelated old-save wipe repaired')
victim, earlier = prepare_story_repair
$Trainer.party.clear
check_story(!mod.repair_story_wipe!(true), 'Missing target allowed a repair')
victim, earlier = prepare_story_repair
$Trainer.party.clear
$PokemonStorage[0,1] = victim
check_story(mod.repair_story_wipe! && $Trainer.party.include?(victim) && !$PokemonStorage[0,1], 'Boxed sole survivor was not returned to party')
victim, earlier = prepare_story_repair
$Trainer.party = (1..6).collect do |index|
  pokemon = PokeBattle_Pokemon.new(PBSpecies::PIDGEY, 5, $Trainer)
  pokemon.nuzlocke_dead = true
  pokemon.hp = 0
  pokemon
end
displaced = $Trainer.party[0]
$PokemonStorage[0,1] = victim
check_story(mod.repair_story_wipe! && $Trainer.party[0].equal?(victim) && $PokemonStorage[0,1].equal?(displaced), 'Full dead party swap lost a Pokemon')
puts 'PASS ordinary prison wipes, unrelated legacy deaths, missing targets and boxed sole-survivor recovery'

module PZHardcoreNuzlocke
  class << self
    attr_accessor :story_test_confirm, :story_test_messages, :story_test_choices
    def show_info(message, title=nil); story_test_messages << message; end
    def confirm_choice(*args); story_test_confirm; end
    def choose(title, commands)
      raise 'Unexpected story repair menu' if story_test_choices.empty?
      value = story_test_choices.shift
      value == :repair ? commands.index(t(:story_repair_title)) : value
    end
  end
end
prepare_story_repair(true)
mod.story_test_messages = []
mod.story_test_confirm = false
check_story(!mod.open_story_wipe_repair && mod.state[:failed], 'Cancelled repair changed run')
check_story(mod.story_test_messages.include?(mod.t(:story_repair_legacy)), 'Missing old-save ambiguity warning')
mod.story_test_confirm = true
mod.story_test_choices = [:repair, -1]
mod.open_menu
check_story(mod.active? && mod.story_test_choices.empty?, 'Challenges repair menu route failed')
[:es,:en,:fr].each do |language|
  mod.set_language(language)
  check_story(mod.t(:story_repair_title) != 'story_repair_title', 'Repair translation missing')
end
puts 'PASS repair menu, cancellation, explicit old-save warning, confirmation and translations'
