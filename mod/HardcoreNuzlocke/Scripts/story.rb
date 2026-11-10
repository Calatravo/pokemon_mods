# encoding: UTF-8

module PZHardcoreNuzlocke
  # Only these prison dreams are exempt. canlose=true on its own does not
  # exempt a normal trainer, a boss, or any other scripted battle.
  STORY_BATTLES = [[248, 2, :CINTIA, 173, 16], [251, 1, :FERROFAZ, 177, 20]]

  def self.story_battle_exempt?
    !!@story_battle_exempt
  end

  def self.story_battle_candidate?(trainer, party, canlose)
    return false unless active? && canlose && party == 0
    event = current_item_event
    return false unless event && event.respond_to?(:id)
    STORY_BATTLES.any? do |entry|
      next false unless current_map_id == entry[0] && event.id == entry[1]
      expected = PBTrainers.const_get(entry[2]) rescue nil
      trainer == entry[2] || trainer == entry[2].to_s || (!expected.nil? && trainer == expected)
    end
  end

  def self.with_story_battle_exemption
    previous = @story_battle_exempt
    @story_battle_exempt = true
    begin
      result = yield
      # The native Nuzlocke heal skips fainted Pokemon, including in canlose
      # battles. Recover living participants before returning to map events.
      $Trainer.party.each do |pokemon|
        next if !pokemon || dead?(pokemon) || (pokemon.isEgg? rescue false)
        if pokemon.hp <= 0
          pokemon.healHP
          pokemon.healStatus
        end
      end
      result
    ensure
      @story_battle_exempt = previous
    end
  end

  def self.install_story_battle_hook
    Object.class_eval do
      unless method_defined?(:pzn_story_original_trainer_battle) || private_method_defined?(:pzn_story_original_trainer_battle)
        alias_method :pzn_story_original_trainer_battle, :pbTrainerBattle
        def pbTrainerBattle(trainer, name, speech, double=false, party=0, canlose=false, *rest)
          if PZHardcoreNuzlocke.story_battle_candidate?(trainer, party, canlose)
            PZHardcoreNuzlocke.with_story_battle_exemption do
              pzn_story_original_trainer_battle(trainer, name, speech, double, party, canlose, *rest)
            end
          else
            pzn_story_original_trainer_battle(trainer, name, speech, double, party, canlose, *rest)
          end
        end
        private :pbTrainerBattle
      end
    end
  end

  def self.story_wipe_repair_candidate
    current = state
    return nil unless current && current[:activated] && current[:failed] && !battle_presentation_active?
    entry = current[:deaths][-1]
    return nil unless entry && entry[:personal_id] && current[:failed_at]
    return nil if (entry[:time].to_i - current[:failed_at].to_i).abs > 2
    map_id = entry[:map_id]
    context = current[:failure_context]
    map_id = context[:map_id] if !map_id && context.is_a?(Hash)
    if map_id
      return nil unless STORY_BATTLES.any? { |battle| battle[0] == map_id }
    else
      # Releases before this fix stored only a grouped area name. A prison
      # death cannot prove which battle caused it: require explicit attestation
      # in the UI, never repair legacy saves automatically.
      return nil unless defined?($game_variables) && $game_variables
      matches = STORY_BATTLES.any? do |battle|
        next false unless $game_variables[battle[3]].to_i >= battle[4]
        name = area_for(battle[0], nil)[:name]
        entry[:area] == name
      end
      return nil unless matches
    end
    pokemon = nil
    each_owned_pokemon do |owned|
      if dead?(owned) && (owned.personalID rescue nil) == entry[:personal_id] && owned.nuzlocke_death_time == entry[:time]
        pokemon = owned
      end
    end
    pokemon ? {:pokemon=>pokemon, :entry=>entry, :legacy=>map_id.nil?} : nil
  end

  def self.repair_story_wipe!(confirm_legacy=false)
    candidate = story_wipe_repair_candidate
    return false unless candidate && (!candidate[:legacy] || confirm_legacy)
    pokemon = candidate[:pokemon]
    current = state
    # If the sole survivor is boxed, bring it back without discarding another
    # Pokemon. A full, dead party swaps one member into the same box slot.
    boxed = nil
    unless $Trainer.party.include?(pokemon)
      for box in 0...$PokemonStorage.maxBoxes
        for slot in 0...$PokemonStorage.maxPokemon(box)
          boxed = [box, slot] if $PokemonStorage[box, slot].equal?(pokemon)
        end
      end
    end
    old_hp = pokemon.hp
    pokemon.nuzlocke_dead = false
    begin
      pokemon.healHP
      raise 'Story repair did not restore HP' unless pokemon.hp > 0
      pokemon.healStatus
    rescue Exception => error
      pokemon.nuzlocke_dead = true
      pokemon.hp = old_hp
      log_exception('story wipe repair', error)
      return false
    end
    if boxed && !$Trainer.party.any? { |member| member && !dead?(member) && member.hp > 0 && !(member.isEgg? rescue false) }
      if $Trainer.party.length < 6
        $PokemonStorage[boxed[0], boxed[1]] = nil
        $Trainer.party << pokemon
      else
        $PokemonStorage[boxed[0], boxed[1]] = $Trainer.party[0]
        $Trainer.party[0] = pokemon
      end
    end
    current[:story_repairs] << {:time=>Time.now.to_i, :death=>candidate[:entry].clone,
      :failed_at=>current[:failed_at], :legacy_confirmed=>candidate[:legacy]}
    current[:deaths].pop
    pokemon.nuzlocke_death_area = nil
    pokemon.nuzlocke_death_time = nil
    current[:failed] = false
    current[:failed_at] = nil
    current[:failure_context] = nil
    current[:pending_notice] = nil
    current[:pending_cemetery] = $Trainer.party.any? { |member| dead?(member) }
    set_base_nuzlocke(true)
    $PokemonSystem.battlestyle = 1 if defined?($PokemonSystem) && $PokemonSystem && rule?(:set_style)
    enforce_party_level_cap!
    log("Story wipe repaired: #{pokemon.name}; legacy=#{candidate[:legacy]}")
    true
  end

  def self.open_story_wipe_repair
    candidate = story_wipe_repair_candidate
    unless candidate
      show_info(t(:story_repair_unavailable), t(:story_repair_title))
      return false
    end
    show_info(t(:story_repair_help), t(:story_repair_title))
    if candidate[:legacy]
      show_info(t(:story_repair_legacy), t(:story_repair_title))
    end
    return false unless confirm_choice(t(:story_repair_question, candidate[:pokemon].name), t(:story_repair_summary), t(:story_repair_title))
    success = repair_story_wipe!(candidate[:legacy])
    show_info(t(success ? :story_repair_done : :story_repair_unavailable), t(:story_repair_title))
    success
  end
end
