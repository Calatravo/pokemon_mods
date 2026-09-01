# encoding: UTF-8

module PZHardcoreNuzlocke
  RANDOM_RULES = [
    [:progressive,      :random_progressive],
    [:moves,            :random_moves],
    [:evolutions,       :random_evolutions],
    [:evo_similar_bst,  :random_evo_similar_bst],
    [:tm_compat,        :random_tm_compat],
    [:types,            :random_types],
    [:items,            :random_items],
    [:event_items,      :random_event_items],
    [:held_items,       :random_held_items],
    [:trainer_rewards,  :random_trainer_rewards],
    [:semi_random,      :random_semi_random]
  ]

  RANDOM_EXPLANATIONS = {
    :progressive=>:random_progressive_help, :moves=>:random_moves_help,
    :evolutions=>:random_evolutions_help, :evo_similar_bst=>:random_evo_similar_bst_help,
    :tm_compat=>:random_tm_compat_help, :types=>:random_types_help,
    :items=>:random_items_help, :event_items=>:random_event_items_help,
    :held_items=>:random_held_items_help,
    :trainer_rewards=>:random_trainer_rewards_help, :semi_random=>:random_semi_random_help,
    :ability_mode=>:random_ability_help, :generations=>:random_generations_help
  }

  def self.random_state
    current = state
    current ? current[:random] : nil
  end

  def self.random_active?
    current = random_state
    current && current[:enabled] && defined?($game_switches) && $game_switches && $game_switches[409]
  end

  # These graphics identify renewable resource nodes. Their normal drops are
  # deliberately preserved so crafting remains reliable and repeatable nodes
  # cannot become an unlimited source of arbitrary random objects.
  RENEWABLE_ITEM_EVENT_GRAPHICS = [
    "golperoca", "guijarros", "cajamateriales", "arbolito",
    "baya1", "baya2", "baya3", "baya4"
  ]

  def self.current_item_event
    interpreter = nil
    if defined?($game_map) && $game_map && $game_map.respond_to?(:interpreter)
      interpreter = $game_map.interpreter
    end
    if !interpreter && defined?($game_system) && $game_system && $game_system.respond_to?(:map_interpreter)
      interpreter = $game_system.map_interpreter
    end
    return nil if !interpreter || !interpreter.respond_to?(:get_character)
    interpreter.get_character(0)
  rescue Exception => error
    log("item event lookup error: #{error.class}: #{error.message}")
    nil
  end

  def self.renewable_item_event?(event=nil)
    event = current_item_event if !event
    return false if !event || !event.respond_to?(:character_name)
    graphic = event.character_name.to_s.downcase
    RENEWABLE_ITEM_EVENT_GRAPHICS.include?(graphic)
  rescue Exception => error
    log("renewable item lookup error: #{error.class}: #{error.message}")
    false
  end

  def self.with_item_random_policy(policy)
    previous = @item_random_policy
    @item_random_policy = policy
    begin
      yield
    ensure
      @item_random_policy = previous
    end
  end

  def self.with_map_item_random_policy
    event = current_item_event
    policy = if !event
      :original
    elsif renewable_item_event?(event)
      :preserve_all
    else
      :automatic_only
    end
    with_item_random_policy(policy) { yield }
  end

  def self.preserve_current_item?
    @item_random_policy == :preserve_all
  end

  def self.automatic_item_protection_only?
    @item_random_policy == :automatic_only
  end

  def self.event_items_randomized?
    config = random_state
    config && config[:enabled] && config[:event_items] && random_active? && !config[:semi_random]
  end

  def self.import_existing_random!
    config = random_state
    return if !config || config[:enabled]
    return if !defined?($game_switches) || !$game_switches || !$game_switches[409]
    config[:progressive] = !!$PokemonGlobal.progressive_random
    config[:moves] = !!$PokemonGlobal.enable_random_moves
    config[:evolutions] = !!$PokemonGlobal.random_evos
    config[:evo_similar_bst] = !!$PokemonGlobal.random_evos_similar_bst
    config[:tm_compat] = !!$PokemonGlobal.enable_random_tm_compat
    config[:types] = !!$PokemonGlobal.enable_random_types
    config[:items] = !!$PokemonGlobal.random_items_enabled
    config[:event_items] = false if !config.has_key?(:event_items)
    config[:held_items] = !!$PokemonGlobal.random_held_items
    config[:trainer_rewards] = !!$PokemonGlobal.random_items_from_trainers
    config[:semi_random] = !!$PokemonGlobal.semi_random
    config[:ability_mode] = $PokemonGlobal.random_ability_mode || :FULL_RANDOM_ABS
    config[:generations] = ($PokemonGlobal.random_gens || [1, 2, 3, 4, 5, 6, 7, 8, 9]).clone
    config[:enabled] = true
    config[:locked] = true
  rescue Exception => error
    log("import random error: #{error.class}: #{error.message}")
  end

  def self.call_global(method_name, *arguments)
    Object.new.send(method_name, *arguments)
  end

  def self.apply_random_config!
    config = random_state
    return false if !config || !defined?($PokemonGlobal) || !$PokemonGlobal || !defined?($game_switches) || !$game_switches
    $game_switches[409] = true
    $PokemonGlobal.semi_random = config[:semi_random]
    $PokemonGlobal.random_gens = config[:generations].clone
    call_global(:enable_random)
    $PokemonGlobal.progressive_random = config[:progressive]
    $PokemonGlobal.enable_random_moves = config[:moves]
    $PokemonGlobal.random_evos = config[:evolutions]
    $PokemonGlobal.random_evos_similar_bst = config[:evo_similar_bst]
    $PokemonGlobal.enable_random_tm_compat = config[:tm_compat]
    $PokemonGlobal.enable_random_types = config[:types]
    $PokemonGlobal.random_items_enabled = config[:items]
    $PokemonGlobal.random_held_items = config[:held_items]
    $PokemonGlobal.random_items_from_trainers = config[:trainer_rewards]
    $PokemonGlobal.semi_random = config[:semi_random]
    $PokemonGlobal.random_ability_mode = config[:ability_mode]
    $PokemonGlobal.random_gens = config[:generations].clone
    $PokemonGlobal.ability_hash = nil
    $PokemonGlobal.random_abs_pokemon = nil if $PokemonGlobal.respond_to?(:random_abs_pokemon=)
    config[:enabled] = true
    config[:locked] = true
    log("Randomizer activated: #{config.inspect}")
    true
  rescue Exception => error
    log("apply_random_config error: #{error.class}: #{error.message}")
    false
  end

  def self.disable_unapplied_random!
    return if !defined?($game_switches) || !$game_switches
    $game_switches[409] = false if !random_state[:enabled]
  end

  def self.mark_first_setup_requested
    current = state
    return if !current || current[:first_run_setup_done]
    current[:pending_first_setup] = true
  end
end
