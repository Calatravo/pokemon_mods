# encoding: UTF-8

module PZHardcoreNuzlocke
  NOVICE_DEFAULTS = {
    :revives_per_gym=>0, :heal_percent=>0, :cure_status=>false,
    :exp_percent=>100, :revive_stage=>nil, :revives_used=>0,
    :revive_history=>[], :prompted=>false
  }

  def self.novice_state
    current = state
    return nil unless current
    current[:novice] = {} unless current[:novice].is_a?(Hash)
    config = current[:novice]
    NOVICE_DEFAULTS.each do |key, value|
      config[key] = value.is_a?(Array) ? value.clone : value unless config.has_key?(key)
    end
    config
  end

  def self.novice_badges
    return 0 unless defined?($Trainer) && $Trainer
    $Trainer.numbadges.to_i
  end

  def self.novice_revives_left
    config = novice_state
    return 0 unless config
    badges = novice_badges
    # Only new progress refreshes the allowance. Changing or disabling the
    # setting never erases spending, and unused revives are not banked.
    if config[:revive_stage].nil? || badges > config[:revive_stage]
      config[:revive_stage] = badges
      config[:revives_used] = 0
    end
    [config[:revives_per_gym].to_i - config[:revives_used].to_i, 0].max
  end

  def self.novice_revival_candidates
    result = []
    each_owned_pokemon do |pokemon|
      result << pokemon if dead?(pokemon) && !(pokemon.isEgg? rescue false)
    end
    result
  end

  def self.novice_revive!(pokemon)
    return false if battle_presentation_active? || !active? || novice_revives_left <= 0
    return false unless novice_revival_candidates.include?(pokemon)
    # Keep the historical death entry; only this Pokemon's current death mark
    # is removed. No items, ordinary healing or PC actions bypass the quota.
    old_hp = pokemon.hp
    pokemon.nuzlocke_dead = false
    begin
      pokemon.healHP
      raise 'Revival did not restore HP' unless pokemon.hp > 0
      pokemon.healStatus
    rescue Exception => error
      pokemon.nuzlocke_dead = true
      pokemon.hp = old_hp
      log_exception('novice revival', error)
      return false
    end
    config = novice_state
    config[:revives_used] += 1
    config[:revive_history] << {
      :personal_id=>(pokemon.personalID rescue nil), :name=>pokemon.name,
      :time=>Time.now.to_i, :badges=>novice_badges
    }
    pokemon.nuzlocke_death_area = nil
    pokemon.nuzlocke_death_time = nil
    log("Novice revival: #{pokemon.name}; remaining=#{novice_revives_left}")
    true
  end

  def self.process_novice_recovery!
    current = state
    return unless current && current[:pending_novice_recovery]
    return if battle_presentation_active?
    current[:pending_novice_recovery] = false
    return unless defined?($Trainer) && $Trainer
    config = novice_state
    $Trainer.party.each do |pokemon|
      next if !pokemon || dead?(pokemon) || pokemon.hp <= 0 || (pokemon.isEgg? rescue false)
      percent = config[:heal_percent].to_i
      if percent > 0
        amount = [pokemon.totalhp * percent / 100, 1].max
        pokemon.hp = [pokemon.hp + amount, pokemon.totalhp].min
      end
      pokemon.healStatus if config[:cure_status]
    end
  end

  def self.with_novice_exp(enabled)
    previous = @novice_exp_context
    @novice_exp_context = enabled
    begin
      yield
    ensure
      @novice_exp_context = previous
    end
  end

  def self.novice_exp_gain(gain)
    return gain unless @novice_exp_context && gain.to_i > 1
    config = novice_state
    config ? gain * config[:exp_percent].to_i / 100 : gain
  end

  def self.cap_novice_exp(current, result, growth)
    return result unless @novice_exp_context && active? && rule?(:level_caps)
    return result if current_level_cap >= 100 || novice_state[:exp_percent] <= 100
    maximum = PBExperience.pbGetStartExperience(current_level_cap + 1, growth) - 1
    [result, [current, maximum].max].min
  end

  def self.open_novice_intro
    config = novice_state
    return unless config && !config[:prompted]
    accepted = confirm_choice(t(:novice_intro_question), t(:novice_intro_help), t(:novice_title))
    open_novice_setup if accepted
    config[:prompted] = true
  end

  def self.choose_novice_value(key, values, labels, help)
    config = novice_state
    show_info(t(help), t("novice_#{key}".to_sym))
    commands = []
    values.each_with_index do |value, index|
      commands << "[#{config[key] == value ? 'X' : ' '}] #{labels[index]}"
    end
    commands << t(:back)
    choice = choose(t("novice_#{key}".to_sym), commands)
    return if choice < 0 || choice >= values.length || values[choice] == config[key]
    if confirm_choice(t(:novice_value_question, labels[choice]), t(help), t(:novice_title))
      novice_revives_left if key == :revives_per_gym
      config[key] = values[choice]
    end
  end

  def self.open_novice_revival
    unless active? && novice_revives_left > 0
      show_info(t(:novice_revive_unavailable), t(:novice_revive_action))
      return false
    end
    candidates = novice_revival_candidates
    if candidates.empty?
      show_info(t(:cemetery_empty), t(:novice_revive_action))
      return false
    end
    commands = candidates.collect { |pokemon| "#{pokemon.name} (#{species_name(pokemon.species)}) Nv.#{pokemon.level}" }
    commands << t(:back)
    choice = choose(t(:novice_revive_balance, novice_revives_left), commands)
    return false if choice < 0 || choice >= candidates.length
    pokemon = candidates[choice]
    return false unless confirm_choice(t(:novice_revive_question, pokemon.name), t(:novice_revive_help), t(:novice_revive_action))
    success = novice_revive!(pokemon)
    show_info(success ? t(:novice_revive_done, pokemon.name, novice_revives_left) : t(:novice_revive_unavailable), t(:novice_revive_action))
    success
  end

  def self.novice_menu_commands
    config = novice_state
    multiplier = config[:exp_percent] == 150 ? 'x1.5' : "x#{config[:exp_percent] / 100}"
    [
      "#{t(:novice_revives_per_gym)}: #{config[:revives_per_gym]}",
      t(:novice_revive_balance, novice_revives_left),
      "#{t(:novice_heal_percent)}: #{config[:heal_percent]}%",
      "[#{config[:cure_status] ? 'X' : ' '}] #{t(:novice_cure_status)}",
      "#{t(:novice_exp_percent)}: #{multiplier}",
      t(:learning_option), t(:type_chart), t(:apply_back)
    ]
  end

  def self.open_novice_setup
    config = novice_state
    return false unless config
    loop do
      choice = choose(t(:novice_title), novice_menu_commands)
      case choice
      when 0
        values = (0..10).to_a
        choose_novice_value(:revives_per_gym, values, values.collect { |n| n == 0 ? t(:inactive) : n.to_s }, :novice_revives_help)
      when 1 then open_novice_revival
      when 2
        choose_novice_value(:heal_percent, [0, 25, 50, 100], [t(:inactive), '25%', '50%', '100%'], :novice_heal_help)
      when 3
        if confirm_toggle(t(:novice_cure_status), t(:novice_cure_help), config[:cure_status])
          config[:cure_status] = !config[:cure_status]
        end
      when 4
        choose_novice_value(:exp_percent, [100, 150, 200], ['x1', 'x1.5', 'x2'], :novice_exp_help)
      when 5 then open_learning_setup
      when 6 then open_type_chart
      else return true
      end
    end
  end

  def self.install_novice_hooks
    PokeBattle_Battle.class_eval do
      unless method_defined?(:pzn_novice_original_gain_exp)
        alias_method :pzn_novice_original_gain_exp, :pbGainEXP
        def pbGainEXP(*args)
          PZHardcoreNuzlocke.with_novice_exp(!!@internalbattle) { pzn_novice_original_gain_exp(*args) }
        end
      end
      if method_defined?(:pbGainEXPR) && !method_defined?(:pzn_novice_original_gain_capture_exp)
        alias_method :pzn_novice_original_gain_capture_exp, :pbGainEXPR
        def pbGainEXPR(*args)
          PZHardcoreNuzlocke.with_novice_exp(!!@internalbattle) { pzn_novice_original_gain_capture_exp(*args) }
        end
      end
    end
    class << PBExperience
      unless method_defined?(:pzn_novice_original_add_exp)
        alias_method :pzn_novice_original_add_exp, :pbAddExperience
        def pbAddExperience(current, gain, growth)
          result = pzn_novice_original_add_exp(current, PZHardcoreNuzlocke.novice_exp_gain(gain), growth)
          PZHardcoreNuzlocke.cap_novice_exp(current, result, growth)
        end
      end
    end
  end
end

class PZNoviceMenuOption
  def name; PZHardcoreNuzlocke.t(:novice_title); end
  def values; [PZHardcoreNuzlocke.t(:open)]; end
  attr_accessor :description
  def get; 0; end
  def set(value); end
  def next(current); 0; end
  def prev(current); 0; end
end
