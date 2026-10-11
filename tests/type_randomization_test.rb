# encoding: UTF-8
# Run in a fresh Ruby process; compatible with the game's Ruby 1.8 runtime.
# PZN_RANDOM_TYPES_SOURCE optionally exercises the extracted RandomMain script.
module PBTypes
  NORMAL = 0
  QMARKS = 9
  FAIRY = 18
  def self.maxValue; 18; end
  def self.isPseudoType?(type); type == QMARKS; end
end
module RandomizedChallenge
  INVALID_TYPES = [PBTypes::QMARKS]
end
module PZHardcoreNuzlocke
  def self.log(message); end
end
Metadata = Struct.new(:random_types, :enable_random_types, :semi_random)
def random_enabled?; $game_switches[409]; end
def random_types_enabled?; $PokemonGlobal.enable_random_types; end
def semi_random_mode?; $PokemonGlobal.semi_random; end

class PokeBattle_Pokemon
  attr_reader :species
  def initialize(species, first=0, second=0)
    @species, @original_first, @original_second = species, first, second
  end
  def type1_random; @original_first; end
  def type2_random; @original_second; end
  # RandomMain currently caches nil because its sampling loop never starts.
  def type1
    return type1_random if semi_random_mode? || !random_enabled? || !random_types_enabled?
    $PokemonGlobal.random_types[@species] ||= [nil]
    $PokemonGlobal.random_types[@species][0]
  end
  def type2
    return type2_random if semi_random_mode? || !random_enabled? || !random_types_enabled?
    type1
    stored = $PokemonGlobal.random_types[@species]
    stored.push(nil) if stored.length < 2
    stored[1]
  end
end

source_path = ENV['PZN_RANDOM_TYPES_SOURCE']
if source_path && source_path.length > 0
  source = File.open(source_path, 'rb') { |file| file.read }.gsub("\r\n", "\n")
  start = source.index("  def type1\n")
  finish = source.index('  def isCompatibleWithMove?', start) if start
  raise 'RandomMain type methods not found' unless start && finish
  PokeBattle_Pokemon.class_eval(source[start...finish], source_path)
end
root = File.expand_path('../mod/HardcoreNuzlocke/Scripts', File.dirname(__FILE__))
load File.join(root, 'random.rb')
load File.join(root, 'hooks.rb')
unless ENV['PZN_TEST_UNPATCHED'] == '1'
  2.times { PZHardcoreNuzlocke.install_random_type_hooks }
end

def check_types(value, message)
  raise message unless value
end
def reset_types(table={})
  $PokemonGlobal = Metadata.new(table, true, false)
  $game_switches = []
  $game_switches[409] = true
end
def valid_type?(type)
  type.is_a?(Integer) && type >= 0 && type <= PBTypes.maxValue && type != PBTypes::QMARKS
end

reset_types
bidoof = PokeBattle_Pokemon.new(399, 0, 14) # Normal/Ice in Pokemon Z.
first = bidoof.type1
check_types(valid_type?(first), 'Bidoof primary type is nil or invalid at battle entry')
second = bidoof.type2
check_types(valid_type?(second), 'Bidoof secondary type is nil or invalid at battle entry')
check_types($PokemonGlobal.random_types[399] == [first, second], 'both type slots must be cached')
check_types(PokeBattle_Pokemon.new(399, 0, 14).type2 == second, 'same species rerolled')
$PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
check_types(bidoof.type1 == first && bidoof.type2 == second, 'save reload rerolled types')
single = PokeBattle_Pokemon.new(133)
check_types(valid_type?(single.type2) && single.type1 == single.type2, 'single-type species gained a second type')

# The second slot may be queried before the first, including dual-type species.
reset_types
dual = PokeBattle_Pokemon.new(1, 12, 3)
second = dual.type2
check_types(valid_type?(second) && valid_type?(dual.type1), 'type2-first lookup failed')
check_types(PokeBattle_Pokemon.new(1, 12, 3).type2 == second, 'dual-type species rerolled')

# Repair old saves without replacing valid mappings for this or other species.
[nil, [], [nil], [nil, nil], [9, 99], ['Fire', -1]].each do |broken|
  reset_types({399=>broken, 25=>[13, 13]})
  check_types(valid_type?(bidoof.type1), "old-save primary repair failed: #{broken.inspect}")
  check_types(valid_type?(bidoof.type2), 'old-save secondary repair failed')
  check_types($PokemonGlobal.random_types[25] == [13, 13], 'unrelated mapping replaced')
end
reset_types(nil)
check_types(valid_type?(bidoof.type2), 'missing type table not repaired')
reset_types({1=>[18, nil], 399=>[0, 18]})
check_types(dual.type1 == 18 && valid_type?(dual.type2), 'valid primary type replaced during repair')
table = $PokemonGlobal.random_types
entry = table[399]
check_types(bidoof.type1 == 0 && bidoof.type2 == 18, 'valid saved mapping changed')
check_types(table.equal?($PokemonGlobal.random_types) && entry.equal?(table[399]), 'valid saved objects replaced')
reset_types({1=>[nil, 0]})
check_types(valid_type?(dual.type1) && dual.type2 == 0, 'valid secondary type replaced during repair')

# Sample the whole real type range, including Normal (0) and Fairy (maxValue).
reset_types
srand(2026)
seen = []
600.times do |index|
  pokemon = PokeBattle_Pokemon.new(2000 + index, 12, 3)
  types = [pokemon.type1, pokemon.type2]
  check_types(types.all? { |type| valid_type?(type) }, 'pseudo or out-of-range type generated')
  seen.concat(types)
end
check_types(seen.include?(PBTypes::NORMAL) && seen.include?(PBTypes::FAIRY), 'Normal or Fairy excluded from sampling')

# All three bypasses must leave the saved mappings untouched.
[[false, true, false], [true, false, false], [true, true, true]].each do |enabled, types, semi|
  reset_types({399=>[18, 18]})
  $game_switches[409] = enabled
  $PokemonGlobal.enable_random_types = types
  $PokemonGlobal.semi_random = semi
  check_types(bidoof.type1 == 0 && bidoof.type2 == 14, 'normal or Semi Random types changed')
  check_types($PokemonGlobal.random_types[399] == [18, 18], 'bypass changed cached mapping')
end
puts 'PASS Bidoof types, type2-first, old-save repair, stable mappings, reload, valid range, bypasses and hook idempotency'
