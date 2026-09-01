# encoding: UTF-8

module PZHardcoreNuzlocke
  CONTEXT_IVAR = :@pzn_nuzlocke_context

  def self.pokemon_token(pokemon)
    [pokemon.personalID, pokemon.species]
  rescue Exception
    [pokemon.object_id, species_id(pokemon)]
  end

  def self.battle_context(battle)
    battle.instance_variable_get(CONTEXT_IVAR)
  rescue Exception
    nil
  end

  def self.set_battle_context(battle, context)
    battle.instance_variable_set(CONTEXT_IVAR, context)
  end

  def self.random_encounter_type
    if defined?($PokemonTemp) && $PokemonTemp
      value = $PokemonTemp.encounterType
      return value if value && value.to_i >= 0
    end
    value = @step_encounter_type
    value && value.to_i >= 0 ? value : nil
  rescue Exception
    nil
  end

  def self.with_step_encounter
    previous = @step_encounter_type
    value = $PokemonEncounters.pbEncounterType rescue nil
    @step_encounter_type = value && value.to_i >= 0 ? value : nil
    yield
  ensure
    @step_encounter_type = previous
  end

  def self.begin_wild_battle(battle)
    set_battle_context(battle, nil)
    return if !active?
    opponent = battle.opponent rescue nil
    return if opponent
    wilds = battle.party2 rescue nil
    return if !wilds || wilds.length == 0

    encounter_type = random_encounter_type
    source = encounter_type.nil? ? :static : :random
    counted = source == :random || rule?(:count_statics)
    area = area_for(current_map_id, encounter_type)
    context = {
      :area=>area,
      :source=>source,
      :counted=>counted,
      :allow_all=>!counted,
      :allowed=>[],
      :shiny=>[],
      :duplicates=>{},
      :other=>[],
      :captured=>false,
      :notice=>nil,
      :notice_shown=>false
    }

    if !counted
      context[:notice] = t(:notice_static_exempt, area[:name])
      set_battle_context(battle, context)
      return
    end

    primary = nil
    wilds.each do |pokemon|
      next if !pokemon
      token = pokemon_token(pokemon)
      if rule?(:shiny_clause) && shiny?(pokemon)
        context[:shiny] << token
        next
      end
      duplicate = duplicate_reason(pokemon)
      if duplicate
        context[:duplicates][token] = duplicate
        next
      end
      if !primary
        primary = pokemon
        context[:allowed] << token
      else
        context[:other] << token
      end
    end

    status = zone_status(area)
    if status == :available && primary
      record = zone_record(area, true)
      record[:status] = :encountered
      record[:species] = primary.species
      record[:encountered_at] = Time.now.to_i
      record[:source] = source
      context[:notice] = t(:notice_first, area[:name], species_name(primary.species))
    elsif status == :available && context[:shiny].length > 0
      context[:notice] = t(:notice_shiny, area[:name])
    elsif status == :available
      context[:notice] = t(:notice_dupes, area[:name])
    else
      context[:allowed].clear
      context[:notice] = t(:notice_zone_used, area[:name])
    end
    set_battle_context(battle, context)
  rescue Exception => error
    log("begin_wild_battle error: #{error.class}: #{error.message}")
    set_battle_context(battle, nil)
  end

  def self.show_encounter_notice(battle)
    context = battle_context(battle)
    return if !context || context[:notice_shown] || !context[:notice]
    context[:notice_shown] = true
    battle.pbDisplayPaused(context[:notice])
  rescue Exception => error
    log("notice error: #{error.class}: #{error.message}")
  end

  def self.capture_allowed?(battle, pokemon)
    return [true, nil] if !active?
    context = battle_context(battle)
    return [true, nil] if !context
    token = pokemon_token(pokemon)
    return [true, nil] if context[:allow_all]
    return [true, nil] if context[:shiny].include?(token)
    return [true, nil] if context[:allowed].include?(token)
    if context[:duplicates][token]
      return [false, t(:capture_dupes_block, context[:duplicates][token])]
    end
    if context[:other].include?(token)
      return [false, t(:capture_double_block, context[:area][:name])]
    end
    [false, t(:capture_zone_block, context[:area][:name])]
  end

  def self.restore_blocked_ball(battle, ball)
    if battle.instance_variable_defined?(:@ballcount)
      current = battle.instance_variable_get(:@ballcount).to_i
      battle.instance_variable_set(:@ballcount, current + 1)
    elsif defined?($PokemonBag) && $PokemonBag && $PokemonBag.pbCanStore?(ball)
      $PokemonBag.pbStoreItem(ball)
    end
  rescue Exception => error
    log("restore ball error: #{error.class}: #{error.message}")
  end

  def self.record_battle_capture(battle, pokemon)
    context = battle_context(battle)
    return if !context || !activated?
    token = pokemon_token(pokemon)
    remember_capture(pokemon)
    pokemon.nuzlocke_origin_area = context[:area][:name] if pokemon.respond_to?(:nuzlocke_origin_area=)

    if context[:shiny].include?(token)
      state[:stats][:shiny_extras] += 1
      context[:captured] = true if context[:allowed].length == 0
      return
    end
    if context[:allow_all]
      state[:stats][:statics] += 1 if context[:source] == :static
      context[:captured] = true
      return
    end
    if context[:allowed].include?(token)
      record = zone_record(context[:area], true)
      record[:status] = :caught
      record[:captured_species] = pokemon.species
      record[:captured_name] = pokemon.name
      record[:captured_at] = Time.now.to_i
      state[:stats][:captures] += 1
      state[:stats][:statics] += 1 if context[:source] == :static
      context[:captured] = true
    end
  rescue Exception => error
    log("capture record error: #{error.class}: #{error.message}")
  end

  def self.finish_wild_battle(battle)
    context = battle_context(battle)
    return if !context || !context[:counted]
    record = zone_record(context[:area], false)
    if record && record[:status] == :encountered
      record[:status] = :missed
      record[:missed_at] = Time.now.to_i
      state[:stats][:misses] += 1
    end
  rescue Exception => error
    log("finish_wild_battle error: #{error.class}: #{error.message}")
  ensure
    set_battle_context(battle, nil)
  end

  def self.prepare_gift(pokemon)
    return {:ignored=>true} if !active? || !rule?(:count_gifts)
    area = area_for(current_map_id, nil)
    if rule?(:shiny_clause) && pokemon.respond_to?(:isShiny?) && shiny?(pokemon)
      return {:area=>area, :pokemon=>pokemon, :shiny=>true}
    end
    duplicate = duplicate_reason(pokemon)
    if duplicate
      Kernel.pbMessage(t(:gift_duplicate_block, duplicate))
      return nil
    end
    if zone_status(area) != :available
      Kernel.pbMessage(t(:gift_zone_block, area[:name]))
      return nil
    end
    {:area=>area, :pokemon=>pokemon, :shiny=>false}
  rescue Exception => error
    log("prepare_gift error: #{error.class}: #{error.message}")
    {:ignored=>true}
  end

  def self.finish_gift(token, pokemon)
    return if !token || token[:ignored]
    remember_capture(pokemon)
    if token[:shiny]
      state[:stats][:shiny_extras] += 1
      return
    end
    area = token[:area]
    record = zone_record(area, true)
    record[:status] = :caught
    record[:source] = :gift
    record[:captured_species] = species_id(pokemon)
    record[:captured_name] = species_name(species_id(pokemon))
    record[:captured_at] = Time.now.to_i
    state[:stats][:captures] += 1
    state[:stats][:gifts] += 1
    pokemon.nuzlocke_origin_area = area[:name] if pokemon.respond_to?(:nuzlocke_origin_area=)
  rescue Exception => error
    log("finish_gift error: #{error.class}: #{error.message}")
  end
end
