# encoding: UTF-8

module PZHardcoreNuzlocke
  class << self
    attr_accessor :installed
  end

  def self.log(message)
    File.open(File.join(PZ_HARDCORE_NUZLOCKE_ROOT, "nuzlocke.log"), "ab") do |file|
      file.write("[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{message}\n")
    end
  rescue Exception
  end

  def self.log_exception(label, error)
    trace = error.backtrace ? error.backtrace.join("\n") : "Sin traza"
    log("#{label}: #{error.class}: #{error.message}\n#{trace}")
  end

  def self.safe_ui(label)
    log("UI OPEN: #{label}")
    result = yield
    log("UI CLOSE: #{label}")
    result
  rescue Exception => error
    log_exception("UI ERROR [#{label}]", error)
    begin
      Kernel.pbMessage(t(:safe_ui_error, label))
    rescue Exception
    end
    false
  end

  def self.item_description(item)
    item_id = item
    if item_id.is_a?(String) || item_id.is_a?(Symbol)
      item_id = getID(PBItems, item_id)
    end
    return "" if !item_id || item_id.to_i <= 0
    pbGetMessage(MessageTypes::ItemDescriptions, item_id).to_s
  rescue Exception => error
    log("item description lookup error: #{error.class}: #{error.message}")
    ""
  end

  def self.show_received_item_description(item)
    description = item_description(item)
    return false if description.strip == ""
    Kernel.pbMessage(description)
    true
  rescue Exception => error
    log_exception("item description display error", error)
    false
  end

  def self.default_state
    {
      :version                => Config::VERSION,
      :activated              => false,
      :failed                 => false,
      :locked                 => false,
      :rules                  => Config::DEFAULT_RULES.clone,
      :zones                  => {},
      :caught_species         => [],
      :deaths                 => [],
      :stats                  => {:captures=>0, :misses=>0, :shiny_extras=>0, :gifts=>0, :statics=>0},
      :cemetery_box           => nil,
      :pending_cemetery       => false,
      :pending_notice         => nil,
      :first_run_setup_done   => false,
      :pending_first_setup    => false,
      :random                 => default_random_state,
      :started_at             => nil,
      :failed_at              => nil
    }
  end

  def self.default_random_state
    {
      :enabled=>false,
      :locked=>false,
      :progressive=>true,
      :moves=>true,
      :evolutions=>false,
      :evo_similar_bst=>true,
      :tm_compat=>true,
      :types=>false,
      :items=>true,
      :held_items=>true,
      :trainer_rewards=>false,
      :semi_random=>false,
      :ability_mode=>:FULL_RANDOM_ABS,
      :generations=>[1, 2, 3, 4, 5, 6, 7, 8, 9]
    }
  end

  def self.state
    return nil if !defined?($PokemonGlobal) || !$PokemonGlobal
    current = $PokemonGlobal.pzn_hardcore_state
    if !current.is_a?(Hash)
      current = default_state
      if $PokemonGlobal.respond_to?(:nuzlocke) && $PokemonGlobal.nuzlocke
        current[:activated] = true
        current[:locked] = true
        current[:started_at] = Time.now.to_i
      end
      $PokemonGlobal.pzn_hardcore_state = current
    end
    migrate_state!(current)
    current
  end

  def self.migrate_state!(value)
    template = default_state
    template.each do |key, default_value|
      value[key] = default_value.is_a?(Hash) ? default_value.clone : default_value if !value.has_key?(key)
    end
    Config::DEFAULT_RULES.each do |key, default_value|
      value[:rules][key] = default_value if !value[:rules].has_key?(key)
    end
    random_template = default_random_state
    value[:random] = random_template.clone if !value[:random].is_a?(Hash)
    random_template.each do |key, default_value|
      value[:random][key] = default_value.is_a?(Array) ? default_value.clone : default_value if !value[:random].has_key?(key)
    end
    value[:version] = Config::VERSION
    value
  end

  def self.activated?
    current = state
    current && current[:activated]
  end

  def self.active?
    current = state
    enabled = current && current[:activated] && !current[:failed]
    set_base_nuzlocke(true) if enabled
    enabled
  end

  def self.set_base_nuzlocke(value)
    return if !defined?($PokemonGlobal) || !$PokemonGlobal
    $PokemonGlobal.instance_variable_set(:@nuzlocke, !!value)
  end

  def self.rule?(key)
    current = state
    return false if !current
    !!current[:rules][key]
  end

  def self.activate!
    current = state
    return false if !current || current[:activated]
    return false if !defined?($Trainer) || !$Trainer
    current[:activated] = true
    current[:locked] = true
    current[:failed] = false
    current[:started_at] = Time.now.to_i
    Config::FORCED_RULES.each { |key| current[:rules][key] = true }
    set_base_nuzlocke(true)
    $PokemonSystem.battlestyle = 1 if defined?($PokemonSystem) && $PokemonSystem && rule?(:set_style)
    seed_owned_species!
    enforce_party_level_cap!
    log("Challenge activated")
    true
  end

  def self.fail_run!
    current = state
    return if !current || current[:failed]
    current[:failed] = true
    current[:failed_at] = Time.now.to_i
    current[:pending_notice] = t(:run_failed_notice)
    set_base_nuzlocke(false)
    log("Challenge failed")
  end

  def self.current_map_id
    return $game_map.map_id if defined?($game_map) && $game_map
    0
  end

  def self.map_name(map_id)
    if defined?($data_mapinfos) && $data_mapinfos && $data_mapinfos[map_id]
      return $data_mapinfos[map_id].name.to_s
    end
    t(:map_fallback, map_id)
  rescue Exception
    t(:map_fallback, map_id)
  end

  def self.area_index
    @area_index ||= begin
      index = {}
      Config::AREAS.each do |key, data|
        localized_name = language == :es ? data[0] : map_name(data[1][0])
        localized_name = data[0] if !localized_name || localized_name == ""
        data[1].each { |map_id| index[map_id] = [key.to_s, localized_name] }
      end
      index
    end
  end

  def self.parent_area(map_id)
    checked = {}
    cursor = map_id
    20.times do
      return area_index[cursor] if area_index[cursor]
      break if checked[cursor]
      checked[cursor] = true
      break if !defined?($data_mapinfos) || !$data_mapinfos || !$data_mapinfos[cursor]
      parent_id = $data_mapinfos[cursor].parent_id rescue 0
      break if !parent_id || parent_id <= 0 || parent_id == cursor
      cursor = parent_id
    end
    nil
  end

  def self.encounter_method(encounter_type)
    return ["land", t(:method_ground)] if encounter_type.nil?
    pairs = []
    if defined?(EncounterTypes)
      pairs << [EncounterTypes::Water, "water", t(:method_surf)] if EncounterTypes.const_defined?(:Water)
      pairs << [EncounterTypes::OldRod, "fishing", t(:method_fishing)] if EncounterTypes.const_defined?(:OldRod)
      pairs << [EncounterTypes::GoodRod, "fishing", t(:method_fishing)] if EncounterTypes.const_defined?(:GoodRod)
      pairs << [EncounterTypes::SuperRod, "fishing", t(:method_fishing)] if EncounterTypes.const_defined?(:SuperRod)
    end
    pairs.each { |entry| return [entry[1], entry[2]] if encounter_type == entry[0] }
    ["land", t(:method_ground)]
  rescue Exception
    ["land", t(:method_ground)]
  end

  def self.area_for(map_id=nil, encounter_type=nil)
    map_id = current_map_id if !map_id
    base = nil
    if rule?(:subzones)
      base = ["map_#{map_id}", map_name(map_id)]
    else
      base = parent_area(map_id)
      base = ["map_#{map_id}", map_name(map_id)] if !base
    end
    method = encounter_method(encounter_type)
    if rule?(:shared_methods)
      {:key=>base[0], :name=>base[1], :map_id=>map_id, :method=>method[1]}
    else
      {:key=>"#{base[0]}__#{method[0]}", :name=>"#{base[1]} (#{method[1]})", :map_id=>map_id, :method=>method[1]}
    end
  end

  def self.zone_record(area, create=false)
    current = state
    return nil if !current
    record = current[:zones][area[:key]]
    if !record && create
      record = {:name=>area[:name], :status=>:available, :map_id=>area[:map_id], :method=>area[:method]}
      current[:zones][area[:key]] = record
    end
    record
  end

  def self.zone_status(area)
    record = zone_record(area, false)
    record ? record[:status] : :available
  end

  def self.current_level_cap
    cap = Config::LEVEL_CAPS[0][1]
    return cap if !defined?($game_switches) || !$game_switches
    Config::LEVEL_CAPS.each do |entry|
      switch_id = entry[0]
      cap = entry[1] if switch_id && $game_switches[switch_id]
    end
    cap
  rescue Exception
    100
  end

  def self.maximum_exp_for(pokemon)
    cap = current_level_cap
    return nil if cap >= 100
    PBExperience.pbGetStartExperience(cap + 1, pokemon.growthrate) - 1
  rescue Exception
    nil
  end

  def self.enforce_party_level_cap!
    return if !active? || !rule?(:level_caps) || !defined?($Trainer) || !$Trainer
    $Trainer.party.each do |pokemon|
      next if !pokemon || (pokemon.isEgg? rescue false)
      maximum = maximum_exp_for(pokemon)
      pokemon.exp = maximum if maximum && pokemon.exp > maximum
      pokemon.calcStats rescue nil
      pokemon.hp = pokemon.totalhp if pokemon.hp > pokemon.totalhp
    end
  end

  def self.each_owned_pokemon
    return if !defined?($Trainer) || !$Trainer
    $Trainer.party.each { |pokemon| yield pokemon if pokemon }
    if defined?($PokemonStorage) && $PokemonStorage
      for box in 0...$PokemonStorage.maxBoxes
        for slot in 0...$PokemonStorage.maxPokemon(box)
          pokemon = $PokemonStorage[box, slot]
          yield pokemon if pokemon
        end
      end
    end
  end

  def self.seed_owned_species!
    current = state
    return if !current
    each_owned_pokemon do |pokemon|
      species = pokemon.species rescue nil
      current[:caught_species] << species if species && !current[:caught_species].include?(species)
    end
  end

  def self.species_id(value)
    return value.species if value.respond_to?(:species)
    return getID(PBSpecies, value) if value.is_a?(String) || value.is_a?(Symbol)
    value.is_a?(Integer) ? value : nil
  rescue Exception
    nil
  end

  def self.species_name(species)
    PBSpecies.getName(species)
  rescue Exception
    species.to_s
  end

  def self.shiny?(pokemon)
    pokemon && pokemon.respond_to?(:isShiny?) && pokemon.isShiny?
  rescue Exception
    false
  end

  def self.baby_species(species)
    pbGetBabySpecies(species)
  rescue Exception
    species
  end

  def self.duplicate_reason(pokemon_or_species)
    return nil if !active?
    seed_owned_species!
    species = species_id(pokemon_or_species)
    return nil if !species
    caught = state[:caught_species]
    if rule?(:species_clause) && caught.include?(species)
      return t(:duplicate_species)
    end
    if rule?(:dupes_clause)
      baby = baby_species(species)
      caught.each do |owned_species|
        return t(:duplicate_line) if baby_species(owned_species) == baby
      end
    end
    nil
  end

  def self.remember_capture(pokemon_or_species)
    current = state
    species = species_id(pokemon_or_species)
    return if !current || !species
    current[:caught_species] << species if !current[:caught_species].include?(species)
  end

  def self.status_label(status)
    return t(:status_available) if status == :available
    return t(:status_encountered) if status == :encountered
    return t(:status_caught) if status == :caught
    return t(:status_missed) if status == :missed
    status.to_s.upcase
  end
end
