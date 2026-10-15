# encoding: UTF-8
# Run in a fresh Ruby process; compatible with Ruby 1.8.
module RandomizedChallenge
  SWITCH = 409
end
Metadata = Struct.new(:enable_random_moves, :semi_random, :random_moves)
def random_enabled?; $game_switches[409]; end
def random_moves_on?; random_enabled? && $PokemonGlobal.enable_random_moves; end
def semi_random_mode?; random_enabled? && $PokemonGlobal.semi_random; end

class PokeBattle_Pokemon
  attr_accessor :form
  def initialize; @form = 0; end
  # The fallback includes MultipleForms and EN/FR's legacy switch-only reader.
  def random_getMoveList
    $original_calls += 1
    $lookup.call if $lookup
    return [[1, :FORM_MOVE]] if form == 1
    return [[1, :LEGACY_RANDOM]] if $game_switches[409] || $game_switches[802]
    [[1, :TACKLE], [5, :GROWL]]
  end
  def getMoveList
    return random_getMoveList if semi_random_mode? || !random_moves_on?
    $PokemonGlobal.random_moves[form] ||= [[1, :RANDOM_MOVE], [5, :OTHER_RANDOM_MOVE]]
  end
end
def check_moves(value, message)
  raise message unless value
end
def reset_moves(enabled=true, moves=false, semi=false, legacy=false)
  $game_switches = []
  $game_switches[409] = enabled
  $game_switches[802] = legacy
  $game_switches[23] = true
  $PokemonGlobal = Metadata.new(moves, semi, {})
  $original_calls = 0
  $lookup = nil
end
root = File.expand_path('../mod/HardcoreNuzlocke/Scripts', File.dirname(__FILE__))
load File.join(root, 'random.rb')
load File.join(root, 'hooks.rb')
pokemon = PokeBattle_Pokemon.new
normal = [[1, :TACKLE], [5, :GROWL]]
reset_moves
check_moves(pokemon.getMoveList != normal, 'legacy randomization bug not reproduced')
2.times { PZHardcoreNuzlocke.install_random_move_hooks }

[[false, false], [false, true], [true, true]].each do |moves, semi|
  [false, true, nil].each do |legacy|
    reset_moves(true, moves, semi, legacy)
    before = $game_switches.dup
    check_moves(pokemon.getMoveList == normal, 'disabled or Semi Random moves randomized')
    check_moves(pokemon.getMoveList == normal, 'ordinary learnset changed between lookups')
    check_moves($original_calls == 2, 'original reader called more than once per lookup')
    check_moves($game_switches == before, 'switch state changed after ordinary lookup')
    check_moves($PokemonGlobal.random_moves.empty?, 'ordinary lookup populated random cache')
  end
end
reset_moves(true, false, false, true)
pokemon.form = 1
check_moves(pokemon.getMoveList == [[1, :FORM_MOVE]], 'original form learnset lost')
pokemon.form = 0

reset_moves(true, true)
before = $game_switches.dup
randomized = pokemon.getMoveList
check_moves(randomized != normal && $original_calls == 0, 'enabled randomizer bypassed')
check_moves(pokemon.getMoveList.equal?(randomized), 'random learnset rerolled')
check_moves($game_switches == before, 'enabled lookup changed switches')
$PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
cached = Marshal.dump($PokemonGlobal.random_moves)
$PokemonGlobal.enable_random_moves = false
check_moves(pokemon.getMoveList == normal, 'saved cache overrides disabled option')
check_moves(Marshal.dump($PokemonGlobal.random_moves) == cached, 'saved random cache replaced')
$PokemonGlobal.enable_random_moves = true
check_moves(pokemon.getMoveList == randomized, 're-enabling rerolled saved learnset')

# The independent legacy mode is preserved when Random itself is off.
reset_moves(false, false, false, true)
check_moves(pokemon.getMoveList == [[1, :LEGACY_RANDOM]], 'independent legacy mode changed')
check_moves(!$game_switches[409] && $game_switches[802], 'independent legacy switches changed')
reset_moves(false)
check_moves(pokemon.getMoveList == normal, 'ordinary game changed')

reset_moves(true, false, false, nil)
before = $game_switches.dup
$lookup = proc do
  check_moves(!$game_switches[409] && !$game_switches[802], 'legacy switches active inside original reader')
  PZHardcoreNuzlocke.with_original_move_lookup do
    check_moves(!$game_switches[409] && !$game_switches[802], 'nested lookup re-enabled Random')
  end
  raise 'lookup failure'
end
begin
  pokemon.getMoveList
  raise 'expected lookup failure'
rescue RuntimeError => error
  check_moves(error.message == 'lookup failure', 'wrong lookup error')
end
check_moves($game_switches == before, 'exception leaked switch changes')
$lookup = nil
check_moves(pokemon.getMoveList == normal, 'exception leaked lookup context')
puts 'PASS disabled/enabled/Semi Random moves, legacy switches, form moves, saved cache, nesting, exceptions and hook idempotency'
