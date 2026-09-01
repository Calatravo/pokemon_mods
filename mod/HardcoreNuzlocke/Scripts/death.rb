# encoding: UTF-8

module PZHardcoreNuzlocke
  def self.dead?(pokemon)
    pokemon && pokemon.respond_to?(:nuzlocke_dead) && pokemon.nuzlocke_dead
  rescue Exception
    false
  end

  def self.record_death(pokemon)
    return if !active? || !pokemon || (pokemon.isEgg? rescue false) || dead?(pokemon)
    return if !defined?($Trainer) || !$Trainer || !$Trainer.party || !$Trainer.party.include?(pokemon)
    area = area_for(current_map_id, nil)
    pokemon.nuzlocke_dead = true
    pokemon.nuzlocke_death_area = area[:name]
    pokemon.nuzlocke_death_time = Time.now.to_i
    entry = {
      :name=>pokemon.name,
      :species=>pokemon.species,
      :level=>pokemon.level,
      :area=>area[:name],
      :time=>pokemon.nuzlocke_death_time,
      :personal_id=>(pokemon.personalID rescue nil)
    }
    state[:deaths] << entry
    state[:pending_cemetery] = true
    log("Death: #{entry[:name]} (#{species_name(entry[:species])}) at #{entry[:area]}")
    check_wipe!
  rescue Exception => error
    log("record_death error: #{error.class}: #{error.message}")
  end

  def self.check_wipe!
    return if !active? || !defined?($Trainer) || !$Trainer || !$Trainer.party
    alive = false
    $Trainer.party.each do |pokemon|
      next if !pokemon || (pokemon.isEgg? rescue false)
      if pokemon.hp > 0 && !dead?(pokemon)
        alive = true
        break
      end
    end
    fail_run! if !alive && $Trainer.party.length > 0
  end

  def self.box_empty?(storage, box)
    for slot in 0...storage.maxPokemon(box)
      return false if storage[box, slot]
    end
    true
  end

  def self.cemetery_box_names
    [Config::CEMETERY_NAME, "CEMETERY", "CIMETIERE", "CIMETIÈRE"]
  end

  def self.cemetery_box
    return nil if !defined?($PokemonStorage) || !$PokemonStorage
    storage = $PokemonStorage
    current = state
    saved = current[:cemetery_box]
    if saved && saved >= 0 && saved < storage.maxBoxes
      return saved
    end
    for box in 0...storage.maxBoxes
      if cemetery_box_names.include?(storage[box].name.to_s.upcase)
        current[:cemetery_box] = box
        return box
      end
    end
    (storage.maxBoxes - 1).downto(0) do |box|
      if box_empty?(storage, box)
        storage[box].name = t(:cemetery_box)
        current[:cemetery_box] = box
        return box
      end
    end
    nil
  rescue Exception => error
    log("cemetery_box error: #{error.class}: #{error.message}")
    nil
  end

  def self.process_party_deaths!
    current = state
    return [] if !current || !current[:pending_cemetery] || !active?
    return [] if !defined?($Trainer) || !$Trainer || !defined?($PokemonStorage) || !$PokemonStorage
    box = cemetery_box
    return [] if box.nil?
    moved = []
    ($Trainer.party.length - 1).downto(0) do |index|
      pokemon = $Trainer.party[index]
      next if !dead?(pokemon)
      slot = $PokemonStorage.pbFirstFreePos(box)
      break if slot.nil? || slot < 0
      $Trainer.party.delete_at(index)
      $PokemonStorage[box, slot] = pokemon
      moved << pokemon.name
    end
    still_pending = false
    $Trainer.party.each { |pokemon| still_pending = true if dead?(pokemon) }
    current[:pending_cemetery] = still_pending
    if moved.length > 0
      current[:pending_notice] = t(:cemetery_moved, moved.join(', '), t(:cemetery_box))
    end
    moved
  rescue Exception => error
    log("process cemetery error: #{error.class}: #{error.message}")
    []
  end

  def self.tick
    return if !installed
    process_test_action if respond_to?(:process_test_action)
    in_battle = defined?($game_temp) && $game_temp && $game_temp.in_battle
    process_party_deaths! if !in_battle
    current = state
    if !in_battle && current && current[:pending_notice] && defined?(Kernel) && Kernel.respond_to?(:pbMessage)
      notice = current[:pending_notice]
      current[:pending_notice] = nil
      Kernel.pbMessage(notice)
    end
  rescue Exception => error
    log("tick error: #{error.class}: #{error.message}")
  end
end
