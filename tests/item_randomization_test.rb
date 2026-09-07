# encoding: UTF-8
# Standalone regression checks: ruby --disable-gems tests/item_randomization_test.rb
# The game boundaries below retain its numeric item indexing and delivery paths.
module PBItems
  POTION = 1
  ANTIDOTE = 2
  POLVOBRILLANTE = 3
  BRASACANDENTE = 4
  MONEDAPLATA = 5
  POKEFLUTE = 6
  POKEVIAL = 7
  LLAVEOLIVIER = 8
  HERRAMIENTAS = 9
  BATERIAVOLCANION = 10
  EMBRIONM = 11
  OLDROD = 12
  GOODROD = 13
  SUPERROD = 14
  TICKETBARCO = 15
  TINYMUSHROOM = 16
  MADERA = 17
  SITRUSBERRY = 18
  AMULETOFUEGO = 19
  AURORATICKET = 20
  GENMISTERIOSO = 21
  ITEMPRISION1 = 22
  ITEMPRISION2 = 23
  ITEMPRISION3 = 24
  CABEZAF3 = 25
  BALSAMOSEDANTE = 26
  MARTILLO = 27
  CINCEL = 28
  POKERIDER = 29
  DEXNAV = 30
end
ITEMPOCKET = 3
ITEMUSE = 6
ITEMTYPE = 8

def getID(mod, item)
  mod.const_get(item)
end

def pbIsTechnicalMachine?(item)
  $ItemData[item] && $ItemData[item][ITEMUSE] == 3
end

def pbIsKeyItem?(item)
  $ItemData[item] && $ItemData[item][ITEMTYPE] == 6
end

def pbIsHiddenMachine?(item); false; end
def pbIsMegaStone?(item); false; end

$ItemData = Array.new(31) { Array.new(10, 0) }
(1..30).each { |id| $ItemData[id][ITEMPOCKET] = 5 }
(5..8).each { |id| $ItemData[id][ITEMPOCKET] = 8 }
(5..8).each { |id| $ItemData[id][ITEMTYPE] = 6 }
# EN/FR quest objects 9..11 deliberately retain pocket 5 / type 0.
[12, 13, 14, 15, 20].each do |id|
  $ItemData[id][ITEMPOCKET] = 8
  $ItemData[id][ITEMTYPE] = 6
end
# Custom keys in the guide retain pocket 8 even when EN/FR use type 0.
(22..30).each { |id| $ItemData[id][ITEMPOCKET] = 8 }
$game_switches = []
$game_switches[409] = true

module RandomizedChallenge
  UNRANDOMIZABLE_ITEMS = [PBItems::HERRAMIENTAS, PBItems::BATERIAVOLCANION,
    PBItems::EMBRIONM, PBItems::TINYMUSHROOM, PBItems::MADERA,
    PBItems::SITRUSBERRY, PBItems::AMULETOFUEGO]
  def self.unrandomizable_item?(item)
    id = item.is_a?(Integer) ? item : getID(PBItems, item)
    UNRANDOMIZABLE_ITEMS.include?(id) || pbIsKeyItem?(id)
  end

  def self.determine_random_item(item)
    unrandomizable_item?(item) ? item : PBItems::ANTIDOTE
  end
end

module Kernel
  def self.pbReceiveItem(item, quantity=1)
    item = getID(PBItems, item) unless item.is_a?(Integer)
    $delivered = [item, quantity]
    true
  end

  def self.pbItemBall(item, quantity=1)
    if $map_items_random
      item = RandomizedChallenge.determine_random_item(item)
    end
    item = getID(PBItems, item) unless item.is_a?(Integer)
    $delivered = [item, quantity]
    true
  end
end

root = File.expand_path("../mod/HardcoreNuzlocke/Scripts", File.dirname(__FILE__))
load File.join(root, "core.rb")
load File.join(root, "random.rb")
load(ENV["PZN_TEST_HOOKS"] || File.join(root, "hooks.rb"))

module PZHardcoreNuzlocke
  def self.random_state; @test_random ||= { :enabled=>true, :event_items=>true }; end
  def self.current_item_event; @test_event; end
  def self.test_event=(event); @test_event = event; end
end

PZHardcoreNuzlocke.install_item_randomization_hooks
Event = Struct.new(:character_name)
$map_items_random = true
failures = []
checks = 0
check = lambda do |label, expected, &action|
  checks += 1
  begin
    result = action.call
    raise "expected #{expected.inspect}, got #{$delivered.inspect}" unless $delivered == expected
    raise "delivery return value changed" unless result == true
  rescue StandardError => error
    failures << "#{label}: #{error.class}: #{error.message}"
  end
end

# Actual protected NPC gifts include symbols; also retain strings and numeric IDs.
[:MONEDAPLATA, :POKEFLUTE, :POKEVIAL, :LLAVEOLIVIER,
 :POLVOBRILLANTE, :BRASACANDENTE, :HERRAMIENTAS, :BATERIAVOLCANION,
 :EMBRIONM, :GENMISTERIOSO, :OLDROD, :GOODROD, :SUPERROD, :TICKETBARCO,
 :AURORATICKET, :ITEMPRISION1, :ITEMPRISION2, :ITEMPRISION3, :CABEZAF3,
 :BALSAMOSEDANTE, :MARTILLO, :CINCEL, :POKERIDER, :DEXNAV].each do |name|
  id = getID(PBItems, name)
  [name, name.to_s, id].each do |input|
    check.call("gift #{input.inspect}", [id, 2]) { Kernel.pbReceiveItem(input, 2) }
    PZHardcoreNuzlocke.test_event = Event.new("objeto")
    check.call("pickup #{input.inspect}", [id, 2]) { Kernel.pbItemBall(input, 2) }
  end
end

# The base game's broad exclusions must not stop ordinary NPC/map rewards.
[:TINYMUSHROOM, :MADERA, :SITRUSBERRY, :AMULETOFUEGO].each do |name|
  id = getID(PBItems, name)
  raise "fixture lacks original exclusion" unless RandomizedChallenge.unrandomizable_item?(id)
  PZHardcoreNuzlocke.test_event = Event.new("objeto")
  check.call("originally excluded gift #{name}", [PBItems::ANTIDOTE, 1]) { Kernel.pbReceiveItem(name) }
  check.call("originally excluded pickup #{name}", [PBItems::ANTIDOTE, 1]) { Kernel.pbItemBall(id) }
end

# Olivier's refill calls pbItemBall on a non-resource NPC graphic.
PZHardcoreNuzlocke.test_event = Event.new("olivierow")
[:POLVOBRILLANTE, :BRASACANDENTE].each do |name|
  id = getID(PBItems, name)
  check.call("Olivier refill #{name}", [id, 1]) { Kernel.pbItemBall(id) }
end

check.call("ordinary gift remains random", [PBItems::ANTIDOTE, 3]) do
  Kernel.pbReceiveItem(:POTION, 3)
end
PZHardcoreNuzlocke.test_event = Event.new("objeto")
check.call("ordinary pickup remains random", [PBItems::ANTIDOTE, 1]) do
  Kernel.pbItemBall(PBItems::POTION)
end
PZHardcoreNuzlocke.test_event = Event.new("cajaMateriales")
check.call("renewable resource remains protected", [PBItems::POTION, 1]) do
  Kernel.pbItemBall(PBItems::POTION)
end
PZHardcoreNuzlocke.random_state[:event_items] = false
check.call("disabled random gifts", [PBItems::POTION, 1]) { Kernel.pbReceiveItem(:POTION) }
$map_items_random = false
PZHardcoreNuzlocke.test_event = Event.new("objeto")
check.call("disabled random pickups", [PBItems::POTION, 1]) { Kernel.pbItemBall(PBItems::POTION) }
raise failures.join("\n") unless failures.empty?
puts "PASS: #{checks} item delivery regression checks"
