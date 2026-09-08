# encoding: UTF-8
# ruby --disable-gems tests/starter_moves_test.rb
module RandomizedChallenge
  SWITCH = 409
  STATERS_VARIABLES = [10, 11, 12]
end
$game_switches = []
$game_variables = {10=>1, 11=>2, 12=>3, 42=>4}
$PokemonGlobal = Struct.new(:enable_random_moves, :semi_random, :progressive_random).new(true, false, true)
def pbGet(id); $game_variables[id]; end
def pause_random; $game_switches[409] = false; end
def resume_random; $game_switches[409] = true; end
def random_enabled?; $game_switches[409]; end
def random_moves_on?; random_enabled? && $PokemonGlobal.enable_random_moves; end
def semi_random_mode?; random_enabled? && $PokemonGlobal.semi_random; end

# Original game's starter delivery. PZN_STARTER_SOURCE optionally supplies the
# same method extracted from a supported edition for integration validation.
def give_starter_random(index=0, var=nil, level=5)
  var ||= RandomizedChallenge::STATERS_VARIABLES[index]
  starter = pbGet(var)
  pause_random
  pbAddPokemon(starter, level)
  resume_random
end
load ENV['PZN_STARTER_SOURCE'] if ENV['PZN_STARTER_SOURCE']

class PokeBattle_Pokemon
  attr_reader :species, :level, :moves
  def initialize(species, level)
    @species = random_enabled? ? 999 : species
    @level = level
    @moves = getMoveList.find_all { |pair| pair[0] <= level }.collect { |pair| pair[1] }
  end
  def getMoveList
    raise 'move lookup failure' if $fail_lookup
    return [[1, :TACKLE], [1, :LEER]] unless random_moves_on? && !semi_random_mode?
    $learnsets ||= {}
    $learnsets[@species] ||= [[1, $PokemonGlobal.progressive_random ? :EMBER : :FIREBLAST], [4, :GROWL], [8, :BITE]]
  end
end
def pbAddPokemon(species, level)
  raise 'gift failure' if $fail_gift
  return false if $reject_gift
  $received = PokeBattle_Pokemon.new(species, level)
  raise 'random leaked into gift delivery' if random_enabled?
  true
end

def assert_starter(condition, label)
  raise label unless condition
end
root = File.expand_path('../mod/HardcoreNuzlocke/Scripts', File.dirname(__FILE__))
load File.join(root, 'random.rb')
load File.join(root, 'hooks.rb')
$game_switches[409] = true
give_starter_random
assert_starter($received.moves == [:TACKLE, :LEER], 'original bug not reproduced')
2.times { PZHardcoreNuzlocke.install_random_starter_hooks }
3.times do |index|
  give_starter_random(index)
  assert_starter($received.species == index + 1, 'selected species changed')
  assert_starter($received.moves == [:EMBER, :GROWL], 'starter moves not randomized at its level')
  assert_starter(random_enabled?, 'Random disabled after delivery')
end
saved = Marshal.load(Marshal.dump($learnsets))
give_starter_random(0)
assert_starter(saved == $learnsets, 'existing learnsets rerolled')
$PokemonGlobal.progressive_random = false
give_starter_random(0, 42, 8)
assert_starter($received.species == 4 && $received.level == 8, 'custom starter arguments lost')
assert_starter($received.moves == [:FIREBLAST, :GROWL, :BITE], 'progressive setting not respected')
[[false, true, false], [true, false, false], [true, true, true]].each do |settings|
  $game_switches[409], $PokemonGlobal.enable_random_moves, $PokemonGlobal.semi_random = settings
  give_starter_random
  assert_starter($received.moves == [:TACKLE, :LEER], 'normal/off/semi moves changed')
  assert_starter($game_switches[409] == settings[0], 'original switch state changed')
end
$game_switches[409] = true
$PokemonGlobal.enable_random_moves = true
$PokemonGlobal.semi_random = false
[:gift, :lookup].each do |failure|
  $fail_gift = failure == :gift
  $fail_lookup = failure == :lookup
  begin
    give_starter_random
    raise 'expected failure'
  rescue RuntimeError => error
    assert_starter(error.message == (failure == :gift ? 'gift failure' : 'move lookup failure'), 'wrong failure')
  end
  assert_starter(random_enabled?, 'failure left random paused')
  assert_starter(!PZHardcoreNuzlocke.instance_variable_get(:@starter_random_moves), 'context leaked after error')
end
$fail_gift = $fail_lookup = false
$reject_gift = true
before = $received
give_starter_random
assert_starter($received.equal?(before), 'rejected gift changed Pokemon')
$game_switches[409] = false
assert_starter(PokeBattle_Pokemon.new(7, 5).moves == [:TACKLE, :LEER], 'unrelated Pokemon affected')
puts 'PASS starter bug reproduction, three choices, stable learnsets, level/progressive settings, normal/off/semi modes, failures and hook idempotency'
