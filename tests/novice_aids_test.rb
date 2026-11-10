# encoding: UTF-8
# Run through novice_aids_integration.ps1 for the game's Ruby 1.8 and real data.
def check_novice(condition, message)
  raise message unless condition
end

def reset_novice
  $game_temp = Game_Temp.new
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $PokemonSystem = PokemonSystem.new
  $PokemonGlobal = PokemonGlobalMetadata.new
  $PokemonStorage = PokemonStorage.new
  $Trainer = PokeBattle_Trainer.new('Beginner test', 0)
  $Trainer.party << PokeBattle_Pokemon.new(PBSpecies::BULBASAUR, 5, $Trainer)
  $Trainer.party << PokeBattle_Pokemon.new(PBSpecies::PIDGEY, 5, $Trainer)
end

reset_novice
mod = PZHardcoreNuzlocke
config = mod.novice_state
check_novice(config[:revives_per_gym] == 0 && config[:heal_percent] == 0 && !config[:cure_status] && config[:exp_percent] == 100, 'New game aids must be opt-in')
mod.state.delete(:novice)
mod.state[:first_run_setup_done] = true
check_novice(mod.novice_state[:revives_per_gym] == 0 && mod.state[:first_run_setup_done], 'Existing save migration changed setup')
mod.novice_state[:revive_history] << :test
reset_novice
check_novice(mod.novice_state[:revive_history].empty?, 'Different saves share aid state')
check_novice(mod.activate!, 'Nuzlocke activation failed')
config = mod.novice_state
config[:revives_per_gym] = 2
victim = $Trainer.party[0]
victim.hp = 0
check_novice(mod.dead?(victim), 'Death was not recorded')
deaths = mod.state[:deaths].length
victim.healHP
check_novice(victim.hp == 0, 'Ordinary healing bypassed death')
mod.with_battle_presentation { check_novice(!mod.novice_revive!(victim), 'Revival allowed during combat') }
check_novice(mod.novice_revive!(victim), 'Party revival failed')
check_novice(!mod.dead?(victim) && victim.hp == victim.totalhp, 'Revival did not clear current death')
check_novice(mod.state[:deaths].length == deaths && mod.novice_revives_left == 1, 'Revival lost history or quota')
check_novice(!mod.novice_revive!(victim) && mod.novice_revives_left == 1, 'Living target spent quota')
victim.hp = 0
mod.process_party_deaths!
check_novice(!$Trainer.party.include?(victim), 'Fixture did not move dead Pokemon to storage')
check_novice(mod.novice_revive!(victim) && mod.novice_revives_left == 0, 'Box revival failed')
# The normal PC withdrawal guard must now consider this Pokemon alive.
check_novice(!mod.dead?(victim), 'Revived boxed Pokemon is still blocked by storage guard')
config[:revives_per_gym] = 0
config[:revives_per_gym] = 2
check_novice(mod.novice_revives_left == 0, 'Toggling aid refilled spent quota')
config[:revives_per_gym] = 3
check_novice(mod.novice_revives_left == 1, 'Increasing allowance lost spending')
config[:revives_per_gym] = 2
$Trainer.badges[0] = true
check_novice(mod.novice_revives_left == 2, 'First badge did not refresh allowance')
config[:revives_used] = 1
$Trainer.badges[0] = false
$Trainer.badges[0] = true
check_novice(mod.novice_revives_left == 1, 'Same badge refreshed allowance twice')
$Trainer.badges[1] = true
check_novice(mod.novice_revives_left == 2, 'Second badge did not refresh allowance')
$PokemonGlobal, $Trainer, $PokemonStorage = Marshal.load(Marshal.dump([$PokemonGlobal, $Trainer, $PokemonStorage]))
check_novice(mod.novice_state[:revive_history].length == 2 && mod.novice_revives_left == 2, 'Save reload lost quota or history')
mod.state[:failed] = true
check_novice(!mod.novice_revive!(victim), 'Ended challenge reopened')
puts 'PASS opt-in, old saves, per-save isolation, party/box revivals, ordinary healing, quota edits, badges and serialization'

reset_novice
config = mod.novice_state
config[:heal_percent] = 25
config[:cure_status] = true
living = $Trainer.party[0]
living.hp = 1
living.status = 1
fainted = $Trainer.party[1]
fainted.hp = 0
egg = PokeBattle_Pokemon.new(PBSpecies::PIDGEY, 5, $Trainer)
egg.eggsteps = 10
$Trainer.party << egg
egg_hp = egg.hp
battle = PokeBattle_Battle.allocate
def battle.pzn_hardcore_original_end_battle(canlose=false); :native_result; end
battle.instance_variable_set(:@internalbattle, true)
[0, 2, 3, 5].each do |decision|
  battle.instance_variable_set(:@decision, decision)
  check_novice(battle.pbEndOfBattle == :native_result, 'Battle return changed')
  check_novice(!mod.state[:pending_novice_recovery], 'Recovery scheduled after loss/run/abort')
end
battle.instance_variable_set(:@internalbattle, false)
battle.instance_variable_set(:@decision, 1)
battle.pbEndOfBattle
check_novice(!mod.state[:pending_novice_recovery], 'Recovery scheduled for an external battle')
battle.instance_variable_set(:@internalbattle, true)
[1, 4].each do |decision|
  living.hp = 1
  living.status = 1
  battle.instance_variable_set(:@decision, decision)
  battle.pbEndOfBattle
  mod.with_battle_presentation { mod.process_novice_recovery! }
  check_novice(living.hp == 1 && living.status == 1, 'Healing interrupted presentation')
  mod.process_novice_recovery!
  check_novice(living.hp == 1 + [living.totalhp / 4, 1].max && living.status == 0, 'Post-battle healing amount/status incorrect')
  check_novice(fainted.hp == 0 && egg.hp == egg_hp, 'Automatic healing revived or affected an egg')
  before = living.hp
  mod.process_novice_recovery!
  check_novice(living.hp == before, 'Healing applied twice')
end
config[:heal_percent] = 100
mod.state[:pending_novice_recovery] = true
mod.process_novice_recovery!
check_novice(living.hp == living.totalhp, 'Healing exceeded or failed maximum HP')
config[:heal_percent] = 0
config[:cure_status] = false
living.hp = 1
living.status = 1
mod.state[:pending_novice_recovery] = true
mod.process_novice_recovery!
check_novice(living.hp == 1 && living.status == 1, 'Disabled aids changed the party')
puts 'PASS real battle-end hook, victory/catch boundaries, deferred healing, status, eggs, fainted targets and idempotency'

config[:exp_percent] = 200
growth = living.growthrate
base = living.exp
check_novice(PBExperience.pbAddExperience(base, 100, growth) == base + 100, 'Outside-battle experience multiplied')
mod.with_novice_exp(true) do
  check_novice(PBExperience.pbAddExperience(base, 100, growth) == base + 200, 'x2 experience failed')
  config[:exp_percent] = 150
  check_novice(PBExperience.pbAddExperience(base, 101, growth) == base + 151, 'x1.5 rounding incorrect')
  check_novice(PBExperience.pbAddExperience(base, 1, growth) == base + 1, 'Game cap sentinel multiplied')
  config[:exp_percent] = 200
  mod.activate!
  maximum = PBExperience.pbGetStartExperience(mod.current_level_cap + 1, growth) - 1
  check_novice(PBExperience.pbAddExperience(maximum - 10, 100, growth) == maximum, 'Experience bypassed Nuzlocke cap')
end
begin
  mod.with_novice_exp(true) { raise 'expected failure' }
rescue RuntimeError
end
check_novice(PBExperience.pbAddExperience(base, 100, growth) == base + 100, 'Experience context leaked after exception')
exp_battle = PokeBattle_Battle.allocate
def exp_battle.pzn_novice_original_gain_exp
  pokemon = $Trainer.party[0]
  PBExperience.pbAddExperience(pokemon.exp, 100, pokemon.growthrate)
end
def exp_battle.pzn_novice_original_gain_capture_exp
  pzn_novice_original_gain_exp
end
exp_battle.instance_variable_set(:@internalbattle, true)
check_novice(exp_battle.pbGainEXP == base + 200 && exp_battle.pbGainEXPR == base + 200, 'Battle/catch wrappers did not multiply experience')
exp_battle.instance_variable_set(:@internalbattle, false)
check_novice(exp_battle.pbGainEXP == base + 100, 'External battle experience was changed')
2.times { mod.install_novice_hooks }
check_novice(PokeBattle_Battle.method_defined?(:pzn_novice_original_gain_exp), 'Native battle EXP hook missing')
puts 'PASS real experience function, multipliers, rounding, level caps, exception cleanup and repeated installation'

# Exercise initial flow and live menu routes without waiting on user input.
module PZHardcoreNuzlocke
  class << self
    attr_accessor :test_answers, :test_choices, :test_prompts, :test_menus
    alias_method :novice_test_real_confirm, :confirm_choice
    alias_method :novice_test_real_choose, :choose
    alias_method :novice_test_real_info, :show_info
    def confirm_choice(question, explanation='', title=nil)
      self.test_prompts << question
      raise 'Unexpected confirmation' if test_answers.empty?
      test_answers.shift
    end
    def choose(title, commands)
      self.test_menus << [title, commands]
      raise 'Unexpected menu' if test_choices.empty?
      test_choices.shift
    end
    def show_info(*args); end
  end
end
[false, true].each do |accept|
  reset_novice
  mod.test_prompts = []
  mod.test_menus = []
  mod.test_answers = [false, accept] # Random, then beginner aids.
  mod.test_choices = accept ? [7] : []
  mod.open_post_nuzlocke_first_run_setup
  mod.open_post_nuzlocke_first_run_setup
  check_novice(mod.test_prompts.length == 2 && mod.novice_state[:prompted], 'Intro was repeated or omitted')
  check_novice(mod.test_menus.length == (accept ? 1 : 0), 'No opened menu or Yes omitted menu')
end
# Check the extra prompt is also reached after either challenge wizard.
module PZHardcoreNuzlocke
  class << self
    alias_method :novice_test_real_nuzlocke_setup, :open_nuzlocke_setup
    alias_method :novice_test_real_random_setup, :open_random_setup
    def open_nuzlocke_setup(*args); activate!; end
    def open_random_setup(*args); state[:random][:enabled] = true; true; end
  end
end
[false, true].each do |nuzlocke|
  [false, true].each do |random|
    reset_novice
    mod.set_base_nuzlocke(nuzlocke)
    mod.test_prompts = []
    mod.test_menus = []
    mod.test_answers = [random, true]
    mod.test_choices = [7]
    mod.open_post_nuzlocke_first_run_setup
    check_novice(mod.novice_state[:prompted] && mod.test_answers.empty? && mod.test_choices.empty?, 'Challenge mode skipped novice setup')
    check_novice(!!mod.activated? == nuzlocke && !!mod.state[:random][:enabled] == random, 'Novice setup changed challenge selection')
  end
end
module PZHardcoreNuzlocke
  class << self
    alias_method :open_nuzlocke_setup, :novice_test_real_nuzlocke_setup
    alias_method :open_random_setup, :novice_test_real_random_setup
  end
end
reset_novice
mod.test_answers = [true]
mod.test_choices = [4, 7]
mod.open_first_run_setup
check_novice(mod.novice_state[:prompted] && mod.test_choices.empty?, 'Alternative initial setup omitted novice prompt')
reset_novice
mod.state[:first_run_setup_done] = true
mod.test_answers = []
mod.test_choices = []
mod.open_post_nuzlocke_first_run_setup
mod.test_answers = [true]
mod.test_choices = [0, 3, 7] # Allowance, 3 revives, then return.
mod.open_novice_setup
check_novice(mod.novice_state[:revives_per_gym] == 3 && mod.test_choices.empty?, 'Existing save could not edit aids')
mod.test_answers = []
mod.test_choices = [-1]
mod.choose_novice_value(:revives_per_gym, [0, 1, 2], ['0', '1', '2'], :novice_revives_help)
check_novice(mod.novice_state[:revives_per_gym] == 3, 'Cancelling value selection changed the allowance')
mod.test_choices = [5, 7, -1] # Challenges > Beginner aids > Return > Close.
mod.open_menu
check_novice(mod.test_choices.empty?, 'Pause challenge menu does not route to beginner aids')
options = PokemonOptionScene.new.pbAddOnOptions([])
options = PokemonOptionScene.new.pbAddOnOptions(options)
check_novice(options.find_all { |option| option.is_a?(PZNoviceMenuOption) }.length == 1, 'Options menu entry missing or duplicated')
[:es, :en, :fr].each do |language|
  mod.set_language(language)
  [:novice_title, :novice_revives_help, :novice_heal_help, :novice_exp_help].each do |key|
    check_novice(mod.t(key) != key.to_s, 'Missing aid translation')
  end
end
puts 'PASS initial Yes/No, one-time prompt, existing-save editing, pause/options routes and three languages'

if ENV['PZN_NOVICE_PREVIEW'] && !ENV['PZN_NOVICE_PREVIEW'].empty?
  [:es, :en, :fr].each do |language|
    mod.set_language(language)
    menu = PZFullscreenChoiceMenu.new(mod.t(:novice_title), mod.novice_menu_commands)
    menu.start
    Graphics.update
    bitmap = Graphics.mkxp_snap_to_bitmap
    bitmap.to_file(File.join(ENV['PZN_NOVICE_PREVIEW'], "novice-#{language}.png"))
    bitmap.dispose
    menu.finish
    intro = PZFullscreenConfirmScreen.new(mod.t(:novice_title), mod.t(:novice_intro_help), mod.t(:novice_intro_question))
    intro.start
    Graphics.update
    bitmap = Graphics.mkxp_snap_to_bitmap
    bitmap.to_file(File.join(ENV['PZN_NOVICE_PREVIEW'], "novice-intro-#{language}.png"))
    bitmap.dispose
    intro.finish
  end
  puts 'PASS rendered beginner menu and initial prompt in all three languages'
end
