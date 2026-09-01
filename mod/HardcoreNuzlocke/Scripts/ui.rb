# encoding: UTF-8

module PZHardcoreNuzlocke
  NUZLOCKE_EXPLANATIONS = {
    :permadeath=>"Muerte permanente: cuando un Pokémon llega a 0 PS queda marcado como muerto, no puede revivir y se mueve automáticamente al Cementerio.",
    :first_encounter=>"Solo el primer encuentro válido de cada zona puede capturarse. Debilitarlo o huir consume esa oportunidad.",
    :one_per_area=>"Todas las plantas, pisos y submapas agrupados bajo la misma zona comparten una única captura.",
    :dupes_clause=>"Los encuentros cuya línea evolutiva ya obtuviste se ignoran y no consumen la zona. Su captura queda bloqueada para permitir repetir encuentro.",
    :species_clause=>"Una especie exacta que ya obtuviste se considera repetida y no consume el primer encuentro de la zona.",
    :shiny_clause=>"Un Pokémon shiny se puede capturar aunque la zona ya esté usada. Cuenta como captura extra y no sustituye la captura normal.",
    :level_caps=>"La experiencia se limita al tope mostrado por el progreso de gimnasios. Un Pokémon no podrá superar ese nivel durante la run.",
    :no_battle_items=>"Bloquea objetos de curación, potenciadores y similares durante el combate. Las Poké Balls siguen disponibles cuando la captura es legal.",
    :set_style=>"Fuerza el estilo Fijo: al derrotar un Pokémon rival no se ofrece un cambio gratuito antes de que entre el siguiente.",
    :count_gifts=>"Los Pokémon regalados y huevos consumen el encuentro de la zona donde se reciben. Si la zona está usada, el regalo se bloquea.",
    :count_statics=>"Los Pokémon estáticos y encuentros lanzados por evento consumen la zona igual que un encuentro aleatorio.",
    :shared_methods=>"Hierba, cuevas, Surf y pesca usan la misma oportunidad. Desactivarlo crea una oportunidad independiente por método.",
    :subzones=>"Cada mapa o piso interno cuenta como zona separada. Desactivarlo agrupa pisos y tramos que pertenecen al mismo lugar lógico."
  }

  def self.choose(message, commands)
    PZFullscreenChoiceMenu.new(message, commands).main
  end

  def self.show_info(message, title="Información")
    PZFullscreenInfoScreen.new(title, message).main
  end

  def self.confirm_choice(question, explanation="", title="Confirmar")
    PZFullscreenConfirmScreen.new(title, explanation, question).main
  end

  def self.confirm_toggle(label, explanation, current_value)
    verb = current_value ? "desactivar" : "activar"
    confirm_choice("¿Deseas #{verb} '#{label}'?", explanation, label)
  end

  def self.nuzlocke_rule_commands
    commands = []
    Config::FORCED_RULES.each do |key|
      label = key == :permadeath ? "Muerte permanente" : (key == :first_encounter ? "Primer encuentro" : "Una captura por zona")
      commands << "[FIJO] #{label}"
    end
    Config::CONFIGURABLE_RULES.each do |entry|
      commands << "[#{rule?(entry[0]) ? 'X' : ' '}] #{entry[1]}"
    end
    commands
  end

  def self.open_nuzlocke_setup(activate_on_apply=true)
    current = state
    return false if !current
    locked = current[:locked]
    loop do
      commands = nuzlocke_rule_commands
      commands << (locked ? "Continuar" : "Aplicar y continuar")
      title = locked ? "Nuzlocke activo - solo consulta" : "Configurar Nuzlocke - reglas típicas activas"
      choice = choose(title, commands)
      if choice < 0
        return false
      elsif choice < Config::FORCED_RULES.length
        key = Config::FORCED_RULES[choice]
        show_info(NUZLOCKE_EXPLANATIONS[key] + "\n\nEsta regla es obligatoria en el modo forzado y no se puede desactivar.", "Regla obligatoria")
      elsif choice < Config::FORCED_RULES.length + Config::CONFIGURABLE_RULES.length
        entry = Config::CONFIGURABLE_RULES[choice - Config::FORCED_RULES.length]
        key = entry[0]
        if locked
          show_info(NUZLOCKE_EXPLANATIONS[key] + "\n\nLa run ya comenzó; esta configuración está bloqueada.", "Configuración bloqueada")
        elsif confirm_toggle(entry[1], NUZLOCKE_EXPLANATIONS[key], current[:rules][key])
          current[:rules][key] = !current[:rules][key]
        end
      else
        return true if locked
        if activate_on_apply
          warning = "Al aplicar, la configuración quedará vinculada a este guardado. Las muertes y zonas consumidas no podrán deshacerse."
          next if !confirm_choice("¿Aplicar esta configuración y comenzar el Nuzlocke?", warning, "Aplicar Nuzlocke")
          if activate!
            show_info("Modo Nuzlocke forzado activado. Puedes consultar reglas, zonas y Cementerio desde el menú Desafíos.", "Nuzlocke activado")
            return true
          else
            show_info("No se pudo activar el desafío en este momento.", "Error")
          end
        else
          return true
        end
      end
    end
  end

  def self.random_boolean_commands
    config = random_state
    commands = []
    mode_name = config[:ability_mode] == :FULL_RANDOM_ABS ? "Full Random" : (config[:ability_mode] == :MAP_RANDOM_ABS ? "Mapeo" : "Sin randomizar")
    commands << "Habilidades: #{mode_name}"
    RANDOM_RULES.each do |entry|
      commands << "[#{config[entry[0]] ? 'X' : ' '}] #{entry[1]}"
    end
    commands << "Generaciones: #{config[:generations].join(', ')}"
    commands
  end

  def self.open_ability_setup
    config = random_state
    show_info(RANDOM_EXPLANATIONS[:ability_mode], "Habilidades random")
    modes = [[:FULL_RANDOM_ABS, "Full Random"], [:MAP_RANDOM_ABS, "Mapeo consistente"], [:NO_RANDOM, "Sin randomizar"]]
    commands = modes.collect { |entry| "[#{config[:ability_mode] == entry[0] ? 'X' : ' '}] #{entry[1]}" }
    selected = choose("Elige el modo de habilidades", commands)
    return if selected < 0 || config[:ability_mode] == modes[selected][0]
    if confirm_choice("¿Deseas usar '#{modes[selected][1]}' para las habilidades?", RANDOM_EXPLANATIONS[:ability_mode], "Habilidades random")
      config[:ability_mode] = modes[selected][0]
    end
  end

  def self.open_generation_setup
    config = random_state
    loop do
      commands = []
      1.upto(9) { |generation| commands << "[#{config[:generations].include?(generation) ? 'X' : ' '}] Generación #{generation}" }
      commands << "Aplicar y continuar"
      choice = choose("Generaciones permitidas", commands)
      return if choice < 0 || choice == 9
      generation = choice + 1
      enabled = config[:generations].include?(generation)
      verb = enabled ? "desactivar" : "activar"
      next if !confirm_choice("¿Deseas #{verb} la Generación #{generation}?", RANDOM_EXPLANATIONS[:generations], "Generación #{generation}")
      if enabled
        if config[:generations].length <= 1
          show_info("Debe quedar al menos una generación activa.", "Generaciones")
        else
          config[:generations].delete(generation)
        end
      else
        config[:generations] << generation
        config[:generations].sort!
      end
    end
  end

  def self.open_random_setup(activate_on_apply=true)
    import_existing_random!
    config = random_state
    return false if !config
    locked = config[:locked]
    loop do
      commands = random_boolean_commands
      commands << (locked ? "Continuar" : "Aplicar y continuar")
      title = locked ? "Random activo - solo consulta" : "Configurar Random - ajustes típicos activos"
      choice = choose(title, commands)
      return false if choice < 0
      if choice == 0
        if locked
          show_info(RANDOM_EXPLANATIONS[:ability_mode] + "\n\nLa partida random ya comenzó; esta opción está bloqueada.", "Configuración bloqueada")
        else
          open_ability_setup
        end
      elsif choice >= 1 && choice <= RANDOM_RULES.length
        entry = RANDOM_RULES[choice - 1]
        key = entry[0]
        if locked
          show_info(RANDOM_EXPLANATIONS[key] + "\n\nLa partida random ya comenzó; esta opción está bloqueada.", "Configuración bloqueada")
        elsif confirm_toggle(entry[1], RANDOM_EXPLANATIONS[key], config[key])
          config[key] = !config[key]
        end
      elsif choice == RANDOM_RULES.length + 1
        if locked
          show_info(RANDOM_EXPLANATIONS[:generations] + "\n\nGeneraciones activas: #{config[:generations].join(', ')}", "Generaciones")
        else
          open_generation_setup
        end
      else
        return true if locked
        if activate_on_apply
          warning = "Al aplicar se generan iniciales, tablas, habilidades y demás datos random para este guardado. La configuración quedará bloqueada para mantener consistencia."
          next if !confirm_choice("¿Aplicar esta configuración y activar el modo Random?", warning, "Aplicar Random")
          if apply_random_config!
            show_info("Modo Random activado. La configuración está disponible para consulta desde el menú Desafíos.", "Random activado")
            return true
          else
            show_info("No se pudo activar el randomizador en este momento.", "Error")
          end
        else
          return true
        end
      end
    end
  end

  def self.open_first_run_setup
    current = state
    return true if !current || current[:first_run_setup_done]
    selected_nuzlocke = !!$PokemonGlobal.instance_variable_get(:@nuzlocke)
    selected_random = false
    loop do
      commands = [
        "[#{selected_nuzlocke ? 'X' : ' '}] Modo Nuzlocke",
        "[#{selected_random ? 'X' : ' '}] Modo Random",
        "Configurar Nuzlocke",
        "Configurar Random",
        "Aplicar modos y continuar"
      ]
      choice = choose("Desafíos disponibles desde la primera partida", commands)
      if choice == 0
        explanation = "Activa muerte permanente, primer encuentro por zona y el resto de cláusulas configurables. Puede combinarse con Random para jugar un Randomlocke."
        if confirm_toggle("Modo Nuzlocke", explanation, selected_nuzlocke)
          selected_nuzlocke = !selected_nuzlocke
          open_nuzlocke_setup(false) if selected_nuzlocke
        end
      elsif choice == 1
        explanation = "Randomiza los sistemas elegidos y puede combinarse con Nuzlocke. Las opciones se fijan al iniciar para mantener consistencia."
        if confirm_toggle("Modo Random", explanation, selected_random)
          selected_random = !selected_random
          open_random_setup(false) if selected_random
        end
      elsif choice == 2
        selected_nuzlocke = true
        open_nuzlocke_setup(false)
      elsif choice == 3
        selected_random = true
        open_random_setup(false)
      elsif choice == 4
        set_base_nuzlocke(false)
        activate! if selected_nuzlocke
        apply_random_config! if selected_random
        disable_unapplied_random! if !selected_random
        current[:first_run_setup_done] = true
        current[:pending_first_setup] = false
        show_info("Configuración aplicada. #{selected_nuzlocke && selected_random ? 'Modo Randomlocke activo.' : (selected_nuzlocke ? 'Modo Nuzlocke activo.' : (selected_random ? 'Modo Random activo.' : 'Partida normal seleccionada.'))}", "Configuración aplicada")
        return true
      else
        show_info("Selecciona 'Aplicar modos y continuar' para terminar la configuración inicial.", "Configuración inicial")
      end
    end
  end

  def self.open_post_nuzlocke_first_run_setup
    current = state
    return true if !current || current[:first_run_setup_done]
    selected_nuzlocke = !!$PokemonGlobal.instance_variable_get(:@nuzlocke)

    if selected_nuzlocke && !current[:activated]
      loop do
        break if open_nuzlocke_setup(true)
        warning = "Elegiste Nuzlocke en la pantalla anterior, pero todavía no has aplicado sus reglas."
        if confirm_choice("¿Continuar esta partida sin Nuzlocke?", warning, "Configuración Nuzlocke")
          selected_nuzlocke = false
          set_base_nuzlocke(false)
          break
        end
      end
    else
      set_base_nuzlocke(false) if !selected_nuzlocke
    end

    random_explanation = "Randomiza los sistemas que elijas y puede combinarse con Nuzlocke para crear un Randomlocke. Si respondes Sí, podrás configurar todos los ajustes antes de aplicarlos."
    selected_random = confirm_choice("¿Deseas activar el modo Random?", random_explanation, "Modo Random")
    if selected_random
      loop do
        break if open_random_setup(true)
        warning = "La configuración Random todavía no se ha aplicado."
        if confirm_choice("¿Continuar esta partida sin Random?", warning, "Configuración Random")
          selected_random = false
          disable_unapplied_random!
          break
        end
      end
    else
      disable_unapplied_random!
    end

    current[:first_run_setup_done] = true
    current[:pending_first_setup] = false
    mode = if selected_nuzlocke && selected_random
      "Randomlocke"
    elsif selected_nuzlocke
      "Nuzlocke"
    elsif selected_random
      "Random"
    else
      "Partida normal"
    end
    show_info("Configuración inicial terminada. Modo seleccionado: #{mode}.", "Configuración aplicada")
    true
  end

  def self.open_progress
    current = state
    if !current
      show_info("Carga o inicia una partida para consultar el progreso Nuzlocke.", "Progreso Nuzlocke")
      return false
    end
    if !current[:activated]
      show_info("El modo Nuzlocke todavía no está activo.", "Progreso Nuzlocke")
      return false
    end
    zones = current[:zones].values
    caught = zones.count { |record| record[:status] == :caught }
    missed = zones.count { |record| record[:status] == :missed }
    area = area_for(current_map_id, nil)
    text = "Estado: #{current[:failed] ? 'RUN TERMINADA' : 'EN CURSO'}\n"
    text += "Zona actual: #{area[:name]} - #{status_label(zone_status(area))}\n"
    text += "Capturas de zona: #{caught} | Perdidas: #{missed}\n"
    text += "Shiny extra: #{current[:stats][:shiny_extras]} | Muertes: #{current[:deaths].length}\n"
    text += "Tope de nivel actual: #{current_level_cap}"
    show_info(text, "Progreso Nuzlocke")
  end

  def self.open_zones
    current = state
    if !current
      show_info("Carga o inicia una partida para consultar el registro de zonas.", "Registro de zonas")
      return false
    end
    records = current[:zones].to_a.sort { |a, b| a[1][:name].to_s <=> b[1][:name].to_s }
    if records.length == 0
      show_info("Aún no se ha registrado ningún encuentro de zona.", "Registro de zonas")
      return
    end
    loop do
      commands = records.collect { |entry| "[#{status_label(entry[1][:status])}] #{entry[1][:name]}" }
      commands << "Volver"
      choice = choose("Registro de zonas", commands)
      return if choice < 0 || choice == records.length
      record = records[choice][1]
      text = "#{record[:name]}\nEstado: #{status_label(record[:status])}"
      text += "\nPrimer encuentro: #{species_name(record[:species])}" if record[:species]
      text += "\nCaptura: #{record[:captured_name] || species_name(record[:captured_species])}" if record[:captured_species]
      show_info(text, "Detalle de zona")
    end
  end

  def self.open_cemetery
    current = state
    if !current
      show_info("Carga o inicia una partida para consultar el Cementerio.", "Cementerio")
      return false
    end
    deaths = current[:deaths]
    if deaths.length == 0
      show_info("El Cementerio está vacío.", "Cementerio")
      return
    end
    loop do
      commands = deaths.reverse.collect { |entry| "#{entry[:name]} Nv.#{entry[:level]} - #{entry[:area]}" }
      commands << "Volver"
      choice = choose("Cementerio - #{deaths.length} bajas", commands)
      return if choice < 0 || choice == deaths.length
      entry = deaths.reverse[choice]
      date = Time.at(entry[:time]).strftime("%d/%m/%Y %H:%M") rescue "Fecha desconocida"
      show_info("#{entry[:name]} (#{species_name(entry[:species])})\nNivel #{entry[:level]}\nMurió en #{entry[:area]}\n#{date}", "Cementerio")
    end
  end

  def self.open_menu
    current = state
    if !current
      show_info("Carga o inicia una partida para abrir el menú de desafíos.", "Menú de desafíos")
      return false
    end
    import_existing_random!
    loop do
      nuz_status = !activated? ? "Inactivo" : (current[:failed] ? "Terminado" : "Activo")
      random_status = random_active? ? "Activo" : "Inactivo"
      commands = [
        "Nuzlocke - #{nuz_status}",
        "Random - #{random_status}",
        "Progreso Nuzlocke",
        "Registro de zonas",
        "Cementerio",
        "Cerrar"
      ]
      choice = choose("Menú de desafíos", commands)
      case choice
      when 0 then open_nuzlocke_setup(true)
      when 1 then open_random_setup(true)
      when 2 then open_progress
      when 3 then open_zones
      when 4 then open_cemetery
      else return
      end
    end
  end

  def self.draw_pause_info(sprites, viewport)
    old = sprites["pzn_challenge_hint"] rescue nil
    old.dispose if old && !old.disposed?
    sprite = Sprite.new(viewport)
    sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    sprite.z = viewport.z + 2
    pbSetSystemFont(sprite.bitmap)
    base = Color.new(250, 250, 250)
    shadow = Color.new(75, 75, 75)
    lines = [["[S/R] Desafíos", 10, Graphics.height - 38, 0, base, shadow, true]]
    if active?
      area = area_for(current_map_id, nil)
      lines << ["#{area[:name]}: #{status_label(zone_status(area))}", 10, Graphics.height - 66, 0, base, shadow, true]
    end
    pbDrawTextPositions(sprite.bitmap, lines)
    sprites["pzn_challenge_hint"] = sprite
  rescue Exception => error
    log("pause hint error: #{error.class}: #{error.message}")
  end

  def self.add_pause_menu_option(menu)
    options = menu.instance_variable_get(:@options)
    sprites = menu.instance_variable_get(:@sprites)
    viewport = menu.instance_variable_get(:@viewport)
    global_viewport = menu.instance_variable_get(:@globalVp)
    return false if !options || !sprites || !viewport
    return true if options.any? { |entry| entry && entry[0] == "Desafíos" }

    action = proc do
      sprites.visible = false
      safe_ui("Desafíos desde menú") { open_menu }
      sprites.visible = true
      draw_pause_info(sprites, global_viewport)
      Input.update
    end
    options << ["Desafíos", "optionsA", "optionsB", action]
    count = options.size
    menu.instance_variable_set(:@count, count)

    viewport.rect.height = 24 + 48 * count if viewport.respond_to?(:rect) && viewport.rect
    sprites["bgMid"].zoom_y = 48 * count if sprites["bgMid"]
    sprites["bgBtm"].y = 12 + 48 * count if sprites["bgBtm"]

    index = count - 1
    sprites["txt"].draw([
      "Desafíos", 68, 20 + 48 * index, 0,
      DP_PauseMenu::BaseColor, DP_PauseMenu::ShadowColor
    ])
    icon = Sprite.new(viewport)
    icon.bmp("Graphics/Pictures/DP Pause Menu/optionsA")
    icon.center_origins
    icon.xyz = 39, 36 + 48 * index
    sprites["Desafíos"] = icon
    true
  rescue Exception => error
    log("pause menu option error: #{error.class}: #{error.message}")
    false
  end
end

class PZFullscreenChoiceMenu
  VISIBLE_ROWS = 7
  ROW_HEIGHT = 36
  LIST_TOP = 68

  def initialize(title, commands)
    @title = title.to_s
    @commands = commands || []
    @index = 0
    @top_index = 0
    @ended = false
  end

  def main
    start
    loop do
      Graphics.update
      Input.update
      if Input.repeat?(Input::DOWN)
        move(1)
      elsif Input.repeat?(Input::UP)
        move(-1)
      elsif Input.trigger?(Input::C)
        pbPlayDecisionSE() rescue nil
        return @index
      elsif Input.trigger?(Input::B)
        pbPlayCancelSE() rescue nil
        return -1
      end
    end
  ensure
    finish
  end

  def start
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 999999
    @sprites = {}
    @sprites["background"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    background = @sprites["background"].bitmap
    background.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(23, 35, 55))
    background.fill_rect(12, 12, Graphics.width - 24, Graphics.height - 24, Color.new(42, 59, 83))
    background.fill_rect(18, 18, Graphics.width - 36, Graphics.height - 36, Color.new(224, 232, 240))
    refresh
  end

  def move(delta)
    return if @commands.length == 0
    @index += delta
    @index = @commands.length - 1 if @index < 0
    @index = 0 if @index >= @commands.length
    if @index < @top_index
      @top_index = @index
    elsif @index >= @top_index + VISIBLE_ROWS
      @top_index = @index - VISIBLE_ROWS + 1
    end
    @top_index = 0 if @index == 0
    pbPlayCursorSE() rescue nil
    refresh
  end

  def refresh
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base = Color.new(40, 48, 64)
    shadow = Color.new(184, 192, 208)
    selected_base = Color.new(250, 252, 255)
    selected_shadow = Color.new(28, 76, 105)
    accent = Color.new(31, 91, 145)

    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [[@title, 30, 22, 0, accent, shadow]])
    count = @commands.length == 0 ? "0/0" : "#{@index + 1}/#{@commands.length}"
    pbDrawTextPositions(bitmap, [[count, Graphics.width - 30, 22, 1, accent, shadow]])

    first = @top_index
    last = [first + VISIBLE_ROWS - 1, @commands.length - 1].min
    if last >= first
      for command_index in first..last
        row = command_index - first
        y = LIST_TOP + row * ROW_HEIGHT
        if command_index == @index
          bitmap.fill_rect(26, y, Graphics.width - 52, ROW_HEIGHT - 3, Color.new(45, 112, 139))
          bitmap.fill_rect(26, y, 6, ROW_HEIGHT - 3, Color.new(93, 218, 207))
          text_base = selected_base
          text_shadow = selected_shadow
          prefix = ">"
        else
          shade = row % 2 == 0 ? Color.new(235, 240, 246) : Color.new(228, 235, 242)
          bitmap.fill_rect(26, y, Graphics.width - 52, ROW_HEIGHT - 3, shade)
          text_base = base
          text_shadow = shadow
          prefix = " "
        end
        pbDrawTextPositions(bitmap, [[prefix, 39, y + 2, 0, text_base, text_shadow]])
        pbDrawTextPositions(bitmap, [[@commands[command_index].to_s, 62, y + 2, 0, text_base, text_shadow]])
      end
    end

    footer_y = Graphics.height - 48
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 30, Color.new(42, 59, 83))
    footer_base = Color.new(245, 248, 252)
    footer_shadow = Color.new(19, 29, 43)
    pbDrawTextPositions(bitmap, [
      ["Arr./Ab.: Mover", 30, footer_y - 1, 0, footer_base, footer_shadow],
      ["C/Enter: Elegir", Graphics.width / 2, footer_y - 1, 2, footer_base, footer_shadow],
      ["X/Esc: Atrás", Graphics.width - 30, footer_y - 1, 1, footer_base, footer_shadow]
    ])
  end

  def finish
    return if @ended
    @ended = true
    pbDisposeSpriteHash(@sprites) if @sprites
    @viewport.dispose if @viewport && !@viewport.disposed?
  end
end

class PZFullscreenInfoScreen
  LINES_PER_PAGE = 8
  LINE_HEIGHT = 30
  TEXT_WIDTH = 43

  def initialize(title, text)
    @title = title.to_s
    @text = text.to_s
    @page = 0
    @ended = false
  end

  def main
    start
    loop do
      Graphics.update
      Input.update
      if Input.trigger?(Input::C) || Input.trigger?(Input::RIGHT) || Input.trigger?(Input::DOWN)
        if @page < @pages.length - 1
          @page += 1
          pbPlayCursorSE() rescue nil
          refresh
        else
          pbPlayDecisionSE() rescue nil
          return true
        end
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::UP)
        if @page > 0
          @page -= 1
          pbPlayCursorSE() rescue nil
          refresh
        end
      elsif Input.trigger?(Input::B)
        pbPlayCancelSE() rescue nil
        return true
      end
    end
  ensure
    finish
  end

  def start
    @pages = build_pages
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 999999
    @sprites = {}
    @sprites["background"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    background = @sprites["background"].bitmap
    background.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(23, 35, 55))
    background.fill_rect(12, 12, Graphics.width - 24, Graphics.height - 24, Color.new(42, 59, 83))
    background.fill_rect(18, 18, Graphics.width - 36, Graphics.height - 36, Color.new(224, 232, 240))
    refresh
  end

  def build_pages
    lines = []
    @text.split(/\n/, -1).each do |paragraph|
      if paragraph.length == 0
        lines << ""
        next
      end
      current = ""
      paragraph.split(/\s+/).each do |word|
        candidate = current.length == 0 ? word : current + " " + word
        if current.length > 0 && candidate.length > TEXT_WIDTH
          lines << current
          current = word
        else
          current = candidate
        end
      end
      lines << current if current.length > 0
    end
    lines << "" if lines.length == 0
    pages = []
    offset = 0
    while offset < lines.length
      pages << lines[offset, LINES_PER_PAGE]
      offset += LINES_PER_PAGE
    end
    pages
  end

  def refresh
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base = Color.new(40, 48, 64)
    shadow = Color.new(184, 192, 208)
    accent = Color.new(31, 91, 145)
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [[@title, 30, 22, 0, accent, shadow]])
    if @pages.length > 1
      pbDrawTextPositions(bitmap, [["#{@page + 1}/#{@pages.length}", Graphics.width - 30, 22, 1, accent, shadow]])
    end

    bitmap.fill_rect(26, 68, Graphics.width - 52, 252, Color.new(235, 240, 246))
    @pages[@page].each_with_index do |line, index|
      pbDrawTextPositions(bitmap, [[line, 38, 78 + index * LINE_HEIGHT, 0, base, shadow]])
    end

    footer_y = Graphics.height - 48
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 30, Color.new(42, 59, 83))
    footer = @page < @pages.length - 1 ? "C/Enter: Siguiente   X/Esc: Volver" : "C/Enter o X/Esc: Continuar"
    pbDrawTextPositions(bitmap, [[footer, Graphics.width / 2, footer_y - 1, 2, Color.new(245, 248, 252), Color.new(19, 29, 43)]])
  end

  def finish
    return if @ended
    @ended = true
    pbDisposeSpriteHash(@sprites) if @sprites
    @viewport.dispose if @viewport && !@viewport.disposed?
  end
end

class PZFullscreenConfirmScreen
  TEXT_WIDTH = 43

  def initialize(title, explanation, question)
    @title = title.to_s
    @explanation = explanation.to_s
    @question = question.to_s
    @index = 0
    @ended = false
  end

  def main
    start
    loop do
      Graphics.update
      Input.update
      if Input.trigger?(Input::LEFT) || Input.trigger?(Input::UP)
        set_index(0)
      elsif Input.trigger?(Input::RIGHT) || Input.trigger?(Input::DOWN)
        set_index(1)
      elsif Input.trigger?(Input::C)
        pbPlayDecisionSE() rescue nil
        return @index == 0
      elsif Input.trigger?(Input::B)
        pbPlayCancelSE() rescue nil
        return false
      end
    end
  ensure
    finish
  end

  def start
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 999999
    @sprites = {}
    @sprites["background"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    background = @sprites["background"].bitmap
    background.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(23, 35, 55))
    background.fill_rect(12, 12, Graphics.width - 24, Graphics.height - 24, Color.new(42, 59, 83))
    background.fill_rect(18, 18, Graphics.width - 36, Graphics.height - 36, Color.new(224, 232, 240))
    refresh
  end

  def wrap_text(text, maximum_lines)
    lines = []
    text.split(/\n/, -1).each do |paragraph|
      if paragraph.length == 0
        lines << ""
        next
      end
      current = ""
      paragraph.split(/\s+/).each do |word|
        candidate = current.length == 0 ? word : current + " " + word
        if current.length > 0 && candidate.length > TEXT_WIDTH
          lines << current
          current = word
        else
          current = candidate
        end
      end
      lines << current if current.length > 0
    end
    if lines.length > maximum_lines
      lines = lines[0, maximum_lines]
      lines[maximum_lines - 1] = lines[maximum_lines - 1].to_s + "..."
    end
    lines
  end

  def set_index(value)
    return if @index == value
    @index = value
    pbPlayCursorSE() rescue nil
    refresh
  end

  def refresh
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base = Color.new(40, 48, 64)
    shadow = Color.new(184, 192, 208)
    accent = Color.new(31, 91, 145)
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [[@title, 30, 22, 0, accent, shadow]])

    bitmap.fill_rect(26, 68, Graphics.width - 52, 154, Color.new(235, 240, 246))
    wrap_text(@explanation, 6).each_with_index do |line, index|
      pbDrawTextPositions(bitmap, [[line, 38, 76 + index * 24, 0, base, shadow]])
    end

    bitmap.fill_rect(26, 228, Graphics.width - 52, 56, Color.new(207, 219, 232))
    wrap_text(@question, 2).each_with_index do |line, index|
      pbDrawTextPositions(bitmap, [[line, Graphics.width / 2, 231 + index * 24, 2, accent, shadow]])
    end

    draw_button(bitmap, 34, 290, 212, "Sí", @index == 0)
    draw_button(bitmap, Graphics.width - 246, 290, 212, "No", @index == 1)

    footer_y = Graphics.height - 48
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 30, Color.new(42, 59, 83))
    footer_base = Color.new(245, 248, 252)
    footer_shadow = Color.new(19, 29, 43)
    pbDrawTextPositions(bitmap, [
      ["Izq./Der.", 30, footer_y - 1, 0, footer_base, footer_shadow],
      ["C/Enter: Confirmar", Graphics.width / 2, footer_y - 1, 2, footer_base, footer_shadow],
      ["X/Esc: No", Graphics.width - 30, footer_y - 1, 1, footer_base, footer_shadow]
    ])
  end

  def draw_button(bitmap, x, y, width, label, selected)
    if selected
      bitmap.fill_rect(x, y, width, 36, Color.new(45, 112, 139))
      bitmap.fill_rect(x, y, 6, 36, Color.new(93, 218, 207))
      base = Color.new(250, 252, 255)
      shadow = Color.new(28, 76, 105)
    else
      bitmap.fill_rect(x, y, width, 36, Color.new(228, 235, 242))
      base = Color.new(40, 48, 64)
      shadow = Color.new(184, 192, 208)
    end
    pbDrawTextPositions(bitmap, [[label, x + width / 2, y + 1, 2, base, shadow]])
  end

  def finish
    return if @ended
    @ended = true
    pbDisposeSpriteHash(@sprites) if @sprites
    @viewport.dispose if @viewport && !@viewport.disposed?
  end
end

class PZNuzlockeMenuOption
  attr_reader :values
  attr_reader :name

  def initialize
    @name = _INTL("Desafíos")
    @values = [_INTL("Abrir")]
  end

  def get; 0; end
  def set(value); end
  def next(current); 0; end
  def prev(current); 0; end
end
