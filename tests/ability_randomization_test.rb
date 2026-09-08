# encoding: UTF-8
# ruby --disable-gems tests/ability_randomization_test.rb
module PZHardcoreNuzlocke
  def self.log(message); end
  def self.test_config=(value); @config = value; end
end

class PokeBattle_Pokemon
  def generate_random_ability
    $generated += 1
    100 + $generated
  end

  # Same lookup contract as RandomMain in the supported game editions.
  def ability_map(ret)
    (0...ret.length).each do |i|
      $PokemonGlobal.ability_hash[ret[i][0]] = generate_random_ability unless $PokemonGlobal.ability_hash[ret[i][0]]
      ret[i][0] = $PokemonGlobal.ability_hash[ret[i][0]]
    end
    ret
  end
end

fields = [:semi_random, :random_gens, :progressive_random, :enable_random_moves,
  :random_evos, :random_evos_similar_bst, :enable_random_tm_compat,
  :enable_random_types, :random_items_enabled, :random_held_items,
  :random_items_from_trainers, :random_ability_mode, :ability_hash,
  :random_abs_pokemon]
Metadata = Struct.new(*fields)
def enable_random
  $PokemonGlobal.ability_hash = { 1=>77 }
end

root = File.expand_path('../mod/HardcoreNuzlocke/Scripts', File.dirname(__FILE__))
load File.join(root, 'random.rb')
load File.join(root, 'hooks.rb')
module PZHardcoreNuzlocke
  def self.random_state; @config; end
end
def check(value, message)
  raise message unless value
end

$PokemonGlobal = Metadata.new
$game_switches = []
$generated = 0
PZHardcoreNuzlocke.test_config = { :ability_mode=>:MAP_RANDOM_ABS, :generations=>[1, 2] }
check(PZHardcoreNuzlocke.apply_random_config!, 'setup failed')
check($PokemonGlobal.ability_hash == {}, 'setup must leave an indexable mapping')
pokemon = PokeBattle_Pokemon.new
check(pokemon.ability_map([[1, 0]]) == [[101, 0]], 'new setup lookup failed')

PZHardcoreNuzlocke.install_random_ability_hooks
PZHardcoreNuzlocke.install_random_ability_hooks
$PokemonGlobal.ability_hash = nil
first = pokemon.ability_map([[1, 0], [1, 2]])
check(first == [[102, 0], [102, 2]], 'old save repair must share mappings across slots')
table = $PokemonGlobal.ability_hash
check(PokeBattle_Pokemon.new.ability_map([[1, 1]]) == [[102, 1]], 'mapping changed between Pokemon')
check($PokemonGlobal.ability_hash.equal?(table), 'existing table replaced')
check(pokemon.ability_map([[2, 0]]) == [[103, 0]], 'missing entry was not populated')
check(table[1] == 102, 'existing entry rerolled')
$PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
check(pokemon.ability_map([[1, 0]]) == [[102, 0]], 'mapping changed after save reload')
check($generated == 3, 'unexpected reroll')
puts 'PASS ability setup, old-save repair, stable mappings, save reload and hook idempotency'
