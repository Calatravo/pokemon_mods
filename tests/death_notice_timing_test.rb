# encoding: UTF-8
module PZHardcoreNuzlocke
  def self.installed; true; end
  def self.state; @test_state; end
  def self.active?; !state[:failed]; end
  def self.rule?(key); false; end
  def self.current_map_id; 3; end
  def self.area_for(*args); {:name=>'Test area'}; end
  def self.species_name(species); species.to_s; end
  def self.log(message); end
  def self.t(key, *args); ([key] + args).join(':'); end
  def self.fail_run!; state[:failed] = true; state[:pending_notice] = 'run failed'; end
  def self.reset_test; @test_state = {:deaths=>[], :failed=>false}; end
end
class PokeBattle_Pokemon
  attr_accessor :hp, :exp
  attr_reader :name
  def initialize(name); @name = name; @hp = 20; end
  def healHP; self.hp = 20; end
  def isEgg?; false; end
  def species; 1; end
  def level; 5; end
end
class Scene_Map
  def update; :map_updated; end
end
class PokeBattle_Battle
  def pbStartBattle(*args); $battle_action.call; :battle_result; end
end
def pbBattleAnimation(*args)
  result = yield
  $animation_tail.call if $animation_tail
  result
end
module Kernel
  def self.pbMessage(notice)
    $notices << notice
    # Message rendering re-enters frame and map updates.
    PZHardcoreNuzlocke.tick
    $scene.update
  end
end
class TestStorage
  attr_reader :entries
  def initialize; @entries=[]; end
  def pbFirstFreePos(box); @entries.length; end
  def []=(box, slot, pokemon); @entries[slot]=pokemon; end
end
root = File.expand_path('../mod/HardcoreNuzlocke/Scripts', File.dirname(__FILE__))
load File.join(root, 'death.rb')
load File.join(root, 'hooks.rb')
module PZHardcoreNuzlocke
  def self.cemetery_box; 0; end
end
PZHardcoreNuzlocke.install_pokemon_hooks
2.times { PZHardcoreNuzlocke.install_death_notice_hooks }
def check_timing(condition, label)
  raise label unless condition
end
def reset_timing(party_size=3)
  PZHardcoreNuzlocke.reset_test
  $Trainer = Struct.new(:party).new((1..party_size).collect { |i| PokeBattle_Pokemon.new("Pokemon#{i}") })
  $PokemonStorage = TestStorage.new
  $game_temp = Struct.new(:in_battle, :transition_processing, :message_window_showing).new(false, false, false)
  $scene = Scene_Map.new
  $notices = []
end
reset_timing
$battle_action = proc do
  2.times do |i|
    $Trainer.party[i].hp = 0
    check_timing($Trainer.party[i].nuzlocke_dead, 'death must still be recorded immediately')
    PZHardcoreNuzlocke.tick
    $scene.update
    check_timing(PZHardcoreNuzlocke.process_party_deaths!.empty?, 'direct transfer during battle')
    check_timing($Trainer.party.length == 3 && $notices.empty?, 'attack/fainting interrupted')
  end
end
$animation_tail = proc do
  PZHardcoreNuzlocke.tick
  $scene.update
  check_timing($Trainer.party.length == 3 && $notices.empty?, 'closing animation interrupted')
end
check_timing(pbBattleAnimation { PokeBattle_Battle.new.pbStartBattle(false) } == :battle_result, 'return value changed')
PZHardcoreNuzlocke.tick
check_timing($notices.empty?, 'Graphics tick delivered notice')
$game_temp.transition_processing = true
$scene.update
check_timing($notices.empty?, 'map transition interrupted')
$game_temp.transition_processing = false
$game_temp.message_window_showing = true
$scene.update
check_timing($notices.empty?, 'existing dialogue interrupted')
$game_temp.message_window_showing = false
check_timing($scene.update == :map_updated, 'map return value changed')
check_timing($Trainer.party.length == 1 && $PokemonStorage.entries.length == 2, 'deaths not moved after battle')
check_timing($notices.length == 1 && $notices[0].include?('Pokemon1') && $notices[0].include?('Pokemon2'), 'combined notice missing')
$scene.update
check_timing($notices.length == 1, 'notice duplicated/reentrant')
reset_timing(1)
$battle_action = proc { $Trainer.party[0].hp = 0; PZHardcoreNuzlocke.tick; $scene.update; check_timing($notices.empty?, 'wipe notice interrupted battle') }
PokeBattle_Battle.new.pbStartBattle(false)
$scene.update
check_timing($notices == ['run failed'], 'wipe notice not delivered on map')
reset_timing
$battle_action = proc { raise 'battle failed' }
begin
  pbBattleAnimation { PokeBattle_Battle.new.pbStartBattle(false) }
rescue RuntimeError => error
  check_timing(error.message == 'battle failed', 'exception changed')
end
check_timing(!PZHardcoreNuzlocke.battle_presentation_active?, 'battle scope leaked after exception')
$Trainer.party[0].hp = 0
$scene.update
check_timing($notices.length == 1, 'field deaths no longer processed')
puts 'PASS attack/faint/end-animation deferral, party integrity, multiple deaths, wipe notice, map return, reentrancy, exceptions and field deaths'
