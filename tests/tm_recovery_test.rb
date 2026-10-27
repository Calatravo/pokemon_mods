# encoding: UTF-8
# Run through tm_randomization_integration.ps1 with the real Ruby, bag and moves.
PokemonGlobalMetadata.class_eval { attr_accessor :pzn_hardcore_state }
module PZHardcoreNuzlocke
  def self.reset_tm_recovery_fixture
    $PokemonGlobal = PokemonGlobalMetadata.new
    $PokemonBag = PokemonBag.new
    $PokemonGlobal.progressive_random = true
    $PokemonGlobal.semi_random = false
    $Trainer.badges = Array.new(8, false)
    random_state[:semi_random] = false
    random_state[:items] = true
    random_state[:event_items] = true
    random_state.delete(:tm_recovery_fixed_from_start)
    $PokemonBag.pbStoreItem(PBItems::TM01)
    $PokemonGlobal.tm_moves = {PBItems::TM01=>PBMoves::TACKLE, PBItems::TM02=>PBMoves::GROWL}
    $PokemonGlobal.given_tm_moves = [PBMoves::TACKLE, PBMoves::GROWL]
    $ItemData[PBItems::TM01][ITEMMACHINE] = PBMoves::TACKLE
    $ItemData[PBItems::TM02][ITEMMACHINE] = PBMoves::GROWL
    state
  end

  def self.tm_recovery_snapshot
    Marshal.dump([$PokemonBag.pockets, $PokemonGlobal.tm_moves,
      $PokemonGlobal.given_tm_moves, $ItemData, state[:tm_recovery]])
  end

  def self.assert_tm_recovery(value, message)
    raise message unless value
  end
end

check = lambda { |value, message| PZHardcoreNuzlocke.assert_tm_recovery(value, message) }
PZHardcoreNuzlocke.reset_tm_recovery_fixture
before = PZHardcoreNuzlocke.tm_recovery_snapshot
[0, -1, 1.5, 999].each do |count|
  result = PZHardcoreNuzlocke.recover_missing_tms!(count)
  check.call(result[:status] == :invalid_count, 'Invalid recovery count accepted')
  check.call(PZHardcoreNuzlocke.tm_recovery_snapshot == before, 'Invalid recovery changed the save')
end
PZHardcoreNuzlocke.random_state[:semi_random] = true
check.call(PZHardcoreNuzlocke.recover_missing_tms!(1)[:status] == :unavailable, 'Semi Random allowed compensation')
PZHardcoreNuzlocke.random_state[:semi_random] = false
PZHardcoreNuzlocke.random_state[:items] = PZHardcoreNuzlocke.random_state[:event_items] = false
check.call(PZHardcoreNuzlocke.recover_missing_tms!(1)[:status] == :unavailable, 'Disabled item randomization allowed compensation')
PZHardcoreNuzlocke.random_state[:items] = true
PZHardcoreNuzlocke.random_state[:tm_recovery_fixed_from_start] = true
check.call(PZHardcoreNuzlocke.recover_missing_tms!(1)[:status] == :unavailable, 'New Random game allowed legacy compensation')
PZHardcoreNuzlocke.reset_tm_recovery_fixture

# Select the first three missing TMs so one already has a shop/cache assignment.
module PZHardcoreNuzlocke
  def self.rand(limit); 0; end
end
result = PZHardcoreNuzlocke.recover_missing_tms!(3)
check.call(result[:status] == :ok && result[:items].uniq.length == 3, 'Compensation count or uniqueness incorrect')
check.call(!result[:items].include?(PBItems::TM01), 'An owned TM was compensated')
check.call(result[:items].all? { |item| $PokemonBag.pbHasItem?(item) }, 'Compensated TM missing from bag')
check.call($PokemonGlobal.tm_moves[PBItems::TM01] == PBMoves::TACKLE, 'Owned TM move overwritten')
check.call($PokemonGlobal.tm_moves[PBItems::TM02] == PBMoves::GROWL, 'Cached TM move rerolled')
result[:items].each do |item|
  move = $PokemonGlobal.tm_moves[item]
  check.call(move == $ItemData[item][ITEMMACHINE], 'Compensation move not saved')
  check.call(PBMoveData.new(move).basedamage <= 70, 'Compensation ignores progressive power cap')
end
class << PZHardcoreNuzlocke; remove_method :rand; end
after = PZHardcoreNuzlocke.tm_recovery_snapshot
check.call(PZHardcoreNuzlocke.recover_missing_tms!(3)[:status] == :already_used, 'Repeated compensation accepted')
$PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
$PokemonBag = Marshal.load(Marshal.dump($PokemonBag))
check.call(PZHardcoreNuzlocke.recover_missing_tms!(3)[:status] == :already_used, 'Reload allowed repeated compensation')
check.call(PZHardcoreNuzlocke.tm_recovery_snapshot == after, 'Repeated claim changed save data')
puts 'PASS compensation count, missing TMs only, preserved assignments, progressive moves and one use across reload'

# A failed second store may already have inserted an item. Restore the entire
# transaction, including earlier stores and changed item/move metadata.
[:return_false, :raise].each do |failure|
  PZHardcoreNuzlocke.reset_tm_recovery_fixture
  $PokemonBag.instance_variable_set(:@recovery_failure, failure)
  class << $PokemonBag
    def pbStoreItem(item, quantity=1)
      result = super
      @recovery_store_calls = (@recovery_store_calls || 0) + 1
      if @recovery_store_calls == 2
        raise 'Injected store failure' if @recovery_failure == :raise
        return false
      end
      result
    end
  end
  before = PZHardcoreNuzlocke.tm_recovery_snapshot
  result = PZHardcoreNuzlocke.recover_missing_tms!(3)
  check.call(result[:status] == (failure == :raise ? :error : :bag_full), 'Store failure hidden')
  check.call(PZHardcoreNuzlocke.tm_recovery_snapshot == before, 'Partial compensation was not rolled back')
  class << $PokemonBag; remove_method :pbStoreItem; end
  check.call(PZHardcoreNuzlocke.recover_missing_tms!(1)[:status] == :ok, 'Failure consumed the compensation')
end
PZHardcoreNuzlocke.reset_tm_recovery_fixture
$PokemonGlobal.given_tm_moves = (1..PBMoves.maxValue).to_a
before = PZHardcoreNuzlocke.tm_recovery_snapshot
check.call(PZHardcoreNuzlocke.recover_missing_tms!(2)[:status] == :no_moves, 'Exhausted move pool not detected')
check.call(PZHardcoreNuzlocke.tm_recovery_snapshot == before, 'Exhausted move pool changed save data')
puts 'PASS partial-store failure/exception rollback and finite exhausted move pool'

# Exercise the real menu actions, replacing only user input and screen display.
root = File.expand_path('../mod/HardcoreNuzlocke', File.dirname(__FILE__))
load File.join(root, 'Locales/i18n.rb')
[:es, :en, :fr].each { |lang| load File.join(root, "Locales/#{lang}.rb") }
load File.join(root, 'Scripts/ui.rb')
module PZHardcoreNuzlocke
  class << self; attr_accessor :recovery_test_answer, :recovery_test_messages, :recovery_test_menu; end
  def self.confirm_choice(*arguments); @recovery_test_answer; end
  def self.show_info(*arguments); (@recovery_test_messages ||= []) << arguments; end
  def self.choose(title, commands)
    raise 'Compensation not accessible from Challenges' unless commands.include?(t(:tm_recovery_title))
    @recovery_test_menu.shift
  end
end
class << Kernel
  def pbMessageChooseNumber(message, params); $recovery_test_amount; end
end
PZHardcoreNuzlocke.reset_tm_recovery_fixture
before = PZHardcoreNuzlocke.tm_recovery_snapshot
$recovery_test_amount = 0
check.call(!PZHardcoreNuzlocke.open_tm_recovery, 'Zero/cancel claimed compensation')
$recovery_test_amount = 2
PZHardcoreNuzlocke.recovery_test_answer = false
check.call(!PZHardcoreNuzlocke.open_tm_recovery, 'Declined compensation delivered items')
check.call(PZHardcoreNuzlocke.tm_recovery_snapshot == before, 'Cancel/decline changed save data')
PZHardcoreNuzlocke.recovery_test_answer = true
check.call(PZHardcoreNuzlocke.open_tm_recovery, 'Confirmed menu compensation failed')
check.call(PZHardcoreNuzlocke.state[:tm_recovery][:items].length == 2, 'Menu quantity ignored')
PZHardcoreNuzlocke.recovery_test_menu = [5,6]
PZHardcoreNuzlocke.open_menu
[:es, :en, :fr].each do |lang|
  [:tm_recovery_title, :tm_recovery_amount, :tm_recovery_help, :tm_recovery_confirm,
   :tm_recovery_done, :tm_recovery_used, :tm_recovery_none, :tm_recovery_error].each do |key|
    check.call(PZHardcoreNuzlocke::I18n.lookup(lang, key) != key.to_s, "Missing translation #{lang}/#{key}")
  end
end
puts 'PASS Challenges menu, cancellation, confirmation, chosen quantity and ES/EN/FR text'

# Finally use the production state reader, rather than the item-test fixture.
class << PZHardcoreNuzlocke
  alias_method :random_state, :pzn_tm_test_real_random_state
end
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonBag = PokemonBag.new
legacy = PZHardcoreNuzlocke.default_state
legacy.delete(:tm_recovery)
legacy[:random].merge!(:enabled=>true, :locked=>true, :items=>true)
$PokemonGlobal.pzn_hardcore_state = Marshal.load(Marshal.dump(legacy))
check.call(PZHardcoreNuzlocke.open_tm_recovery, 'Legacy 1.1.4-shaped state could not use recovery')
$PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
check.call(PZHardcoreNuzlocke.recover_missing_tms!(2)[:status] == :already_used, 'Legacy recovery record lost on reload')
$PokemonGlobal = PokemonGlobalMetadata.new
$PokemonBag = PokemonBag.new
check.call(PZHardcoreNuzlocke.apply_random_config!, 'New Random setup failed')
check.call(!PZHardcoreNuzlocke.tm_recovery_enabled?, 'New Random setup exposes legacy compensation')
puts 'PASS production state migration from old save and exclusion of newly activated Random runs'
