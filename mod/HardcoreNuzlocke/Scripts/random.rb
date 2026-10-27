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

  def self.all_random_tms
    (1..PBItems.maxValue).find_all do |item|
      pbIsTechnicalMachine?(item) && !PBItems.getName(item).to_s.empty?
    end
  end

  def self.missing_random_tms
    all_random_tms.find_all { |item| !$PokemonBag.pbHasItem?(item) }
  end

  def self.tm_recovery_enabled?
    config = random_state
    random_active? && config && !config[:semi_random] && !config[:tm_recovery_fixed_from_start] &&
      (config[:items] || config[:event_items])
  end

  # Old saves retain no ledger of replaced TM rewards. This is an explicit,
  # one-time compensation chosen by the player, not an inferred restoration.
  def self.recover_missing_tms!(amount)
    return {:status=>:unavailable} if !tm_recovery_enabled? || @tm_recovery_busy
    current = state
    return {:status=>:already_used} if current[:tm_recovery]
    available = missing_random_tms
    return {:status=>:invalid_count} if !amount.is_a?(Integer) || amount < 1 || amount > available.length
    return {:status=>:unavailable} if !defined?($Trainer) || !$Trainer

    items = []
    amount.times { items << available.delete_at(rand(available.length)) }
    old_pockets = Marshal.dump($PokemonBag.pockets)
    old_moves = Marshal.dump([$PokemonGlobal.tm_moves, $PokemonGlobal.given_tm_moves])
    old_item_moves = {}
    items.each { |item| old_item_moves[item] = $ItemData[item][ITEMMACHINE] }
    committed = false
    @tm_recovery_busy = true
    begin
      $PokemonGlobal.tm_moves ||= {}
      $PokemonGlobal.given_tm_moves ||= []
      to_generate = items.find_all do |item|
        RandomizedChallenge::RANDOMIZE_TM_MOVES &&
          !RandomizedChallenge::UNRANDOMIZABLE_TMS.include?(item) && !$PokemonGlobal.tm_moves[item]
      end
      pool = []
      unless to_generate.empty?
        progressive = call_global(:progressive_random_on?) && $Trainer.numbadges < 3 &&
          RandomizedChallenge::MT_MOVES_RESPECT_PROGRESSIVE_RANDOM
        # Enumerate once rather than retry indefinitely if the move pool is
        # exhausted. Existing TM assignments, including shops, stay unchanged.
        pool = (1..PBMoves.maxValue).find_all do |move|
          !$PokemonGlobal.tm_moves.values.include?(move) &&
            !call_global(:invalid_move?, progressive, move, false, progressive ? 70 : 0, true)
        end
        return {:status=>:no_moves} if pool.length < to_generate.length
      end
      moves = {}
      items.each do |item|
        move = $PokemonGlobal.tm_moves[item]
        move = pool.delete_at(rand(pool.length)) if to_generate.include?(item)
        moves[item] = move if move
      end
      items.each do |item|
        if moves[item]
          $ItemData[item][ITEMMACHINE] = moves[item]
          $PokemonGlobal.tm_moves[item] = moves[item]
          $PokemonGlobal.given_tm_moves << moves[item] unless $PokemonGlobal.given_tm_moves.include?(moves[item])
        end
        return {:status=>:bag_full} unless $PokemonBag.pbStoreItem(item, 1)
      end
      current[:tm_recovery] = {:items=>items.clone, :at=>Time.now.to_i}
      committed = true
      log("One-time TM compensation: #{items.inspect}")
      {:status=>:ok, :items=>items}
    ensure
      unless committed
        $PokemonBag.instance_variable_set(:@pockets, Marshal.load(old_pockets))
        $PokemonGlobal.tm_moves, $PokemonGlobal.given_tm_moves = Marshal.load(old_moves)
        old_item_moves.each { |item, move| $ItemData[item][ITEMMACHINE] = move }
      end
      @tm_recovery_busy = false
    end
  rescue Exception => error
    log_exception('TM compensation failed', error)
    {:status=>:error}
  end

  def self.valid_random_type?(type)
    type.is_a?(Integer) && type >= 0 && type <= PBTypes.maxValue &&
      !RandomizedChallenge::INVALID_TYPES.include?(type) &&
      (!PBTypes.respond_to?(:isPseudoType?) || !PBTypes.isPseudoType?(type))
  end

  def self.generate_random_type
    types = (0..PBTypes.maxValue).find_all { |type| valid_random_type?(type) }
    raise 'No valid types available for Random' if types.empty?
    types[rand(types.length)]
  end

  # RandomMain's modifier-while never samples its initially nil local, so old
  # saves can contain [nil] or [nil, nil]. Generate both slots together and
  # preserve every valid saved slot rather than rerolling the species table.
  def self.random_types_for(pokemon)
    $PokemonGlobal.random_types = {} unless $PokemonGlobal.random_types.is_a?(Hash)
    table = $PokemonGlobal.random_types
    stored = table[pokemon.species]
    stored = [] unless stored.is_a?(Array)
    return stored if valid_random_type?(stored[0]) && valid_random_type?(stored[1])

    first = valid_random_type?(stored[0]) ? stored[0] : generate_random_type
    second = if valid_random_type?(stored[1])
      stored[1]
    elsif pokemon.type1_random == pokemon.type2_random
      first
    else
      generate_random_type
    end
    table[pokemon.species] = [first, second]
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

  # EN/FR's original move reader randomizes on switches 409/802 without
  # checking enable_random_moves. RandomMain calls this reader when it wants
  # ordinary moves (also in Semi Random); suppress only that legacy fallback.
  def self.with_original_move_lookup
    return yield unless call_global(:random_enabled?)
    switches = [RandomizedChallenge::SWITCH, 802]
    previous = switches.collect { |switch| $game_switches[switch] }
    begin
      switches.each { |switch| $game_switches[switch] = false }
      yield
    ensure
      switches.each_with_index { |switch, index| $game_switches[switch] = previous[index] }
    end
  end

  # The game's starter gift pauses all randomization to keep the chosen species.
  # Allow only its move-list lookup to see the player's original Random settings.
  def self.with_starter_random_moves
    previous = @starter_random_moves
    switch = RandomizedChallenge::SWITCH
    enabled = $game_switches[switch]
    @starter_random_moves = call_global(:random_moves_on?) && !call_global(:semi_random_mode?)
    begin
      yield
    ensure
      @starter_random_moves = previous
      $game_switches[switch] = enabled
    end
  end

  def self.with_starter_move_lookup
    return yield unless @starter_random_moves
    switch = RandomizedChallenge::SWITCH
    previous = $game_switches[switch]
    begin
      $game_switches[switch] = true
      yield
    ensure
      $game_switches[switch] = previous
    end
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
    # ability_map fills missing entries lazily, but requires a Hash to index.
    $PokemonGlobal.ability_hash = {}
    $PokemonGlobal.random_abs_pokemon = nil if $PokemonGlobal.respond_to?(:random_abs_pokemon=)
    config[:enabled] = true
    config[:locked] = true
    config[:tm_recovery_fixed_from_start] = true
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
