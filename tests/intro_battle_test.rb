# encoding: UTF-8
module PBSpecies
  BIDOOF = 399
end
module PZHardcoreNuzlocke
  def self.state; @test_state; end
  def self.active?; state[:activated] && !state[:failed]; end
  def self.current_map_id; @map; end
  def self.current_item_event; @event; end
  def self.log(message); end
  def self.area_for(*args); {:name=>'test'}; end
  def self.species_name(id); id.to_s; end
  def self.fail_run!; state[:failed] = true; end
  def self.setup_intro_test(event=3, map=2)
    @test_state = {:activated=>true, :failed=>false, :deaths=>[]}
    @event = Struct.new(:id).new(event)
    @map = map
    $game_switches = []
  end
end
class IntroPokemon
  attr_accessor :hp, :nuzlocke_dead, :nuzlocke_death_area, :nuzlocke_death_time
  def initialize; @hp = 20; end
  def healHP; @hp = 20; end
  def isEgg?; false; end
  def name; 'Starter'; end
  def species; 1; end
  def level; 5; end
end
def pbWildBattle(species, level, variable=nil, canescape=true, canlose=false, *rest)
  $last_arguments = [species, level, variable, canescape, canlose, rest]
  raise 'battle error' if $battle_error
  pokemon = $Trainer.party[0]
  pokemon.hp = 0
  PZHardcoreNuzlocke.record_death(pokemon)
  PZHardcoreNuzlocke.check_wipe!
  false
end
def assert_intro(condition, message)
  raise message unless condition
end
root = File.expand_path('../mod/HardcoreNuzlocke/Scripts', File.dirname(__FILE__))
load File.join(root, 'death.rb')
load File.join(root, 'hooks.rb')
2.times { PZHardcoreNuzlocke.install_intro_battle_hook }
Trainer = Struct.new(:party)
[3, 9, 15].each do |event|
  PZHardcoreNuzlocke.setup_intro_test(event)
  $Trainer = Trainer.new([IntroPokemon.new])
  assert_intro(pbWildBattle(PBSpecies::BIDOOF, 2, 7, false, false, true) == false, 'battle return changed')
  assert_intro($last_arguments == [399, 2, 7, false, true, [true]], 'battle arguments lost')
  assert_intro(!PZHardcoreNuzlocke.state[:failed], 'intro loss failed the run')
  assert_intro(PZHardcoreNuzlocke.state[:deaths].empty?, 'intro death recorded')
  assert_intro(!$Trainer.party[0].nuzlocke_dead && $Trainer.party[0].hp > 0, 'starter not restored')
  assert_intro(PZHardcoreNuzlocke.state[:intro_battle_completed], 'intro exemption not consumed')
  pbWildBattle(PBSpecies::BIDOOF, 2)
  assert_intro(PZHardcoreNuzlocke.state[:failed], 'second defeat must count')
end
[[4, 2, 399, 2, false], [3, 3, 399, 2, false], [3, 2, 1, 2, false],
 [3, 2, 399, 3, false], [3, 2, 399, 2, true]].each do |event, map, species, level, completed|
  PZHardcoreNuzlocke.setup_intro_test(event, map)
  $game_switches[65] = completed
  $Trainer = Trainer.new([IntroPokemon.new])
  pbWildBattle(species, level)
  assert_intro(PZHardcoreNuzlocke.state[:failed], 'unrelated battle received exemption')
  assert_intro(!$last_arguments[4], 'unrelated canlose changed')
end
PZHardcoreNuzlocke.setup_intro_test
$Trainer = Trainer.new([IntroPokemon.new])
$battle_error = true
begin
  pbWildBattle(399, 2)
rescue RuntimeError => error
  assert_intro(error.message == 'battle error', 'wrong error')
end
assert_intro(!PZHardcoreNuzlocke.intro_battle_exempt?, 'exception leaked protection')
assert_intro(!PZHardcoreNuzlocke.state[:intro_battle_completed], 'failed call consumed exemption')
puts 'PASS introductory loss, starter recovery, all three choices, later defeat, event/species/map/level boundaries and exception cleanup'
