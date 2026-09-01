# encoding: UTF-8

module PZHardcoreNuzlocke
  NUZLOCKE_EXPLANATIONS = {
    :permadeath=>:rule_permadeath_help, :first_encounter=>:rule_first_encounter_help,
    :one_per_area=>:rule_one_per_area_help, :dupes_clause=>:rule_dupes_clause_help,
    :species_clause=>:rule_species_clause_help, :shiny_clause=>:rule_shiny_clause_help,
    :level_caps=>:rule_level_caps_help, :no_battle_items=>:rule_no_battle_items_help,
    :set_style=>:rule_set_style_help, :count_gifts=>:rule_count_gifts_help,
    :count_statics=>:rule_count_statics_help, :shared_methods=>:rule_shared_methods_help,
    :subzones=>:rule_subzones_help
  }

  def self.choose(message, commands)
    PZFullscreenChoiceMenu.new(message, commands).main
  end

  def self.show_info(message, title=nil)
    title = t(:information_title) if !title
    PZFullscreenInfoScreen.new(title, message).main
  end

  def self.confirm_choice(question, explanation="", title=nil)
    PZFullscreenConfirmScreen.new(title || t(:confirm_title), explanation, question).main
  end

  def self.confirm_toggle(label, explanation, current_value)
    verb = current_value ? t(:deactivate_verb) : t(:activate_verb)
    confirm_choice(t(:toggle_question, verb, label), explanation, label)
  end

  def self.nuzlocke_rule_commands
    commands = []
    Config::FORCED_RULES.each do |key|
      label = t("rule_#{key}".to_sym)
      commands << "[#{t(:fixed_prefix)}] #{label}"
    end
    Config::CONFIGURABLE_RULES.each do |entry|
      commands << "[#{rule?(entry[0]) ? 'X' : ' '}] #{t(entry[1])}"
    end
    commands
  end

  def self.open_nuzlocke_setup(activate_on_apply=true)
    current = state
    return false if !current
    locked = current[:locked]
    loop do
      commands = nuzlocke_rule_commands
      commands << (locked ? t(:continue) : t(:apply_continue))
      title = locked ? t(:nuz_active_title) : t(:nuz_config_title)
      choice = choose(title, commands)
      if choice < 0
        return false
      elsif choice < Config::FORCED_RULES.length
        key = Config::FORCED_RULES[choice]
        show_info(t(NUZLOCKE_EXPLANATIONS[key]) + "\n\n" + t(:mandatory_suffix), t(:mandatory_rule))
      elsif choice < Config::FORCED_RULES.length + Config::CONFIGURABLE_RULES.length
        entry = Config::CONFIGURABLE_RULES[choice - Config::FORCED_RULES.length]
        key = entry[0]
        if locked
          show_info(t(NUZLOCKE_EXPLANATIONS[key]) + "\n\n" + t(:locked_suffix), t(:locked_config))
        elsif confirm_toggle(t(entry[1]), t(NUZLOCKE_EXPLANATIONS[key]), current[:rules][key])
          current[:rules][key] = !current[:rules][key]
        end
      else
        return true if locked
        if activate_on_apply
          warning = t(:nuz_apply_warning)
          next if !confirm_choice(t(:nuz_apply_question), warning, t(:nuz_apply_title))
          if activate!
            show_info(t(:nuz_activated), t(:nuz_activated_title))
            return true
          else
            show_info(t(:nuz_activation_error), t(:error_title))
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
    mode_name = config[:ability_mode] == :FULL_RANDOM_ABS ? t(:ability_full) : (config[:ability_mode] == :MAP_RANDOM_ABS ? t(:ability_map) : t(:ability_none))
    commands << "#{t(:abilities)}: #{mode_name}"
    RANDOM_RULES.each do |entry|
      commands << "[#{config[entry[0]] ? 'X' : ' '}] #{t(entry[1])}"
    end
    commands << "#{t(:generations)}: #{config[:generations].join(', ')}"
    commands
  end

  def self.open_ability_setup
    config = random_state
    show_info(t(RANDOM_EXPLANATIONS[:ability_mode]), t(:abilities_random))
    modes = [[:FULL_RANDOM_ABS, t(:ability_full)], [:MAP_RANDOM_ABS, t(:ability_map)], [:NO_RANDOM, t(:ability_none)]]
    commands = modes.collect { |entry| "[#{config[:ability_mode] == entry[0] ? 'X' : ' '}] #{entry[1]}" }
    selected = choose(t(:choose_ability), commands)
    return if selected < 0 || config[:ability_mode] == modes[selected][0]
    if confirm_choice(t(:use_ability_question, modes[selected][1]), t(RANDOM_EXPLANATIONS[:ability_mode]), t(:abilities_random))
      config[:ability_mode] = modes[selected][0]
    end
  end

  def self.open_generation_setup
    config = random_state
    loop do
      commands = []
      1.upto(9) { |generation| commands << "[#{config[:generations].include?(generation) ? 'X' : ' '}] #{t(:generation, generation)}" }
      commands << t(:apply_continue)
      choice = choose(t(:generations_allowed), commands)
      return if choice < 0 || choice == 9
      generation = choice + 1
      enabled = config[:generations].include?(generation)
      verb = enabled ? t(:deactivate_verb) : t(:activate_verb)
      next if !confirm_choice(t(:generation_toggle_question, verb, generation), t(RANDOM_EXPLANATIONS[:generations]), t(:generation, generation))
      if enabled
        if config[:generations].length <= 1
          show_info(t(:generation_required), t(:generations))
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
      commands << (locked ? t(:continue) : t(:apply_continue))
      title = locked ? t(:random_active_title) : t(:random_config_title)
      choice = choose(title, commands)
      return false if choice < 0
      if choice == 0
        if locked
          show_info(t(RANDOM_EXPLANATIONS[:ability_mode]) + "\n\n" + t(:random_locked_suffix), t(:locked_config))
        else
          open_ability_setup
        end
      elsif choice >= 1 && choice <= RANDOM_RULES.length
        entry = RANDOM_RULES[choice - 1]
        key = entry[0]
        if locked
          show_info(t(RANDOM_EXPLANATIONS[key]) + "\n\n" + t(:random_locked_suffix), t(:locked_config))
        elsif confirm_toggle(t(entry[1]), t(RANDOM_EXPLANATIONS[key]), config[key])
          config[key] = !config[key]
        end
      elsif choice == RANDOM_RULES.length + 1
        if locked
          show_info(t(RANDOM_EXPLANATIONS[:generations]) + "\n\n#{t(:generations)}: #{config[:generations].join(', ')}", t(:generations))
        else
          open_generation_setup
        end
      else
        return true if locked
        if activate_on_apply
          warning = t(:random_apply_warning)
          next if !confirm_choice(t(:random_apply_question), warning, t(:random_apply_title))
          if apply_random_config!
            show_info(t(:random_activated), t(:random_activated_title))
            return true
          else
            show_info(t(:random_activation_error), t(:error_title))
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
        "[#{selected_nuzlocke ? 'X' : ' '}] #{t(:mode_nuzlocke)}",
        "[#{selected_random ? 'X' : ' '}] #{t(:mode_random)}",
        t(:configure_nuzlocke),
        t(:configure_random),
        t(:apply_modes)
      ]
      choice = choose(t(:first_run_title), commands)
      if choice == 0
        explanation = t(:mode_nuz_help)
        if confirm_toggle(t(:mode_nuzlocke), explanation, selected_nuzlocke)
          selected_nuzlocke = !selected_nuzlocke
          open_nuzlocke_setup(false) if selected_nuzlocke
        end
      elsif choice == 1
        explanation = t(:mode_random_help)
        if confirm_toggle(t(:mode_random), explanation, selected_random)
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
        result_text = selected_nuzlocke && selected_random ? t(:mode_result_randomlocke) : (selected_nuzlocke ? t(:mode_result_nuzlocke) : (selected_random ? t(:mode_result_random) : t(:mode_result_normal)))
        show_info(t(:configuration_applied, result_text), t(:configuration_title))
        return true
      else
        show_info(t(:finish_initial_hint), t(:initial_config_title))
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
        warning = t(:nuz_not_applied)
        if confirm_choice(t(:continue_without_nuz), warning, t(:nuz_config_title_short))
          selected_nuzlocke = false
          set_base_nuzlocke(false)
          break
        end
      end
    else
      set_base_nuzlocke(false) if !selected_nuzlocke
    end

    random_explanation = t(:random_first_question_help)
    selected_random = confirm_choice(t(:activate_random_question), random_explanation, t(:mode_random))
    if selected_random
      loop do
        break if open_random_setup(true)
        warning = t(:random_not_applied)
        if confirm_choice(t(:continue_without_random), warning, t(:random_config_title_short))
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
      t(:mode_name_randomlocke)
    elsif selected_nuzlocke
      t(:mode_name_nuzlocke)
    elsif selected_random
      t(:mode_name_random)
    else
      t(:mode_name_normal)
    end
    show_info(t(:initial_finished, mode), t(:configuration_title))
    true
  end

  def self.open_progress
    current = state
    if !current
      show_info(t(:load_for_progress), t(:progress_nuz))
      return false
    end
    if !current[:activated]
      show_info(t(:nuz_not_active), t(:progress_nuz))
      return false
    end
    zones = current[:zones].values
    caught = zones.count { |record| record[:status] == :caught }
    missed = zones.count { |record| record[:status] == :missed }
    area = area_for(current_map_id, nil)
    run_status = current[:failed] ? t(:run_terminated) : t(:run_in_progress)
    text = t(:progress_text, run_status, area[:name], status_label(zone_status(area)), caught, missed,
      current[:stats][:shiny_extras], current[:deaths].length, current_level_cap)
    show_info(text, t(:progress_nuz))
  end

  def self.open_zones
    current = state
    if !current
      show_info(t(:load_for_zones), t(:zone_register))
      return false
    end
    records = current[:zones].to_a.sort { |a, b| a[1][:name].to_s <=> b[1][:name].to_s }
    if records.length == 0
      show_info(t(:no_zone_records), t(:zone_register))
      return
    end
    loop do
      commands = records.collect { |entry| "[#{status_label(entry[1][:status])}] #{entry[1][:name]}" }
      commands << t(:back)
      choice = choose(t(:zone_register), commands)
      return if choice < 0 || choice == records.length
      record = records[choice][1]
      text = t(:zone_detail, record[:name], status_label(record[:status]))
      text += "\n" + t(:first_encounter_label, species_name(record[:species])) if record[:species]
      text += "\n" + t(:capture_label, record[:captured_name] || species_name(record[:captured_species])) if record[:captured_species]
      show_info(text, t(:zone_detail_title))
    end
  end

  def self.open_cemetery
    current = state
    if !current
      show_info(t(:load_for_cemetery), t(:cemetery))
      return false
    end
    deaths = current[:deaths]
    if deaths.length == 0
      show_info(t(:cemetery_empty), t(:cemetery))
      return
    end
    loop do
      commands = deaths.reverse.collect { |entry| t(:cemetery_entry, entry[:name], entry[:level], entry[:area]) }
      commands << t(:back)
      choice = choose(t(:cemetery_count, deaths.length), commands)
      return if choice < 0 || choice == deaths.length
      entry = deaths.reverse[choice]
      date = Time.at(entry[:time]).strftime("%d/%m/%Y %H:%M") rescue t(:unknown_date)
      show_info(t(:cemetery_detail, entry[:name], species_name(entry[:species]), entry[:level], entry[:area], date), t(:cemetery))
    end
  end

  def self.open_menu
    current = state
    if !current
      show_info(t(:load_for_challenges), t(:challenge_menu))
      return false
    end
    import_existing_random!
    loop do
      nuz_status = !activated? ? t(:inactive) : (current[:failed] ? t(:terminated) : t(:active))
      random_status = random_active? ? t(:active) : t(:inactive)
      commands = [
        t(:nuz_status, nuz_status),
        t(:random_status, random_status),
        t(:progress_nuz),
        t(:zone_register),
        t(:cemetery),
        t(:close)
      ]
      choice = choose(t(:challenge_menu), commands)
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
    lines = [[t(:pause_challenges), 10, Graphics.height - 38, 0, base, shadow, true]]
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
    return true if options.any? { |entry| entry && entry[0] == t(:challenges) }

    action = proc do
      sprites.visible = false
      safe_ui(t(:challenges)) { open_menu }
      sprites.visible = true
      draw_pause_info(sprites, global_viewport)
      Input.update
    end
    options << [t(:challenges), "optionsA", "optionsB", action]
    count = options.size
    menu.instance_variable_set(:@count, count)

    viewport.rect.height = 24 + 48 * count if viewport.respond_to?(:rect) && viewport.rect
    sprites["bgMid"].zoom_y = 48 * count if sprites["bgMid"]
    sprites["bgBtm"].y = 12 + 48 * count if sprites["bgBtm"]

    index = count - 1
    sprites["txt"].draw([
      t(:challenges), 68, 20 + 48 * index, 0,
      DP_PauseMenu::BaseColor, DP_PauseMenu::ShadowColor
    ])
    icon = Sprite.new(viewport)
    icon.bmp("Graphics/Pictures/DP Pause Menu/optionsA")
    icon.center_origins
    icon.xyz = 39, 36 + 48 * index
    sprites[t(:challenges)] = icon
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

    footer_y = Graphics.height - 72
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 54, Color.new(42, 59, 83))
    footer_base = Color.new(245, 248, 252)
    footer_shadow = Color.new(19, 29, 43)
    pbDrawTextPositions(bitmap, [
      [PZHardcoreNuzlocke.t(:footer_move), 30, footer_y - 1, 0, footer_base, footer_shadow],
      [PZHardcoreNuzlocke.t(:footer_choose), Graphics.width - 30, footer_y - 1, 1, footer_base, footer_shadow],
      [PZHardcoreNuzlocke.t(:footer_back), Graphics.width / 2, footer_y + 23, 2, footer_base, footer_shadow]
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

    footer_y = Graphics.height - 72
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 54, Color.new(42, 59, 83))
    footer = @page < @pages.length - 1 ? PZHardcoreNuzlocke.t(:footer_next_back) : PZHardcoreNuzlocke.t(:footer_continue)
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

    draw_button(bitmap, 34, 290, 212, PZHardcoreNuzlocke.t(:yes), @index == 0)
    draw_button(bitmap, Graphics.width - 246, 290, 212, PZHardcoreNuzlocke.t(:no), @index == 1)

    footer_y = Graphics.height - 72
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 54, Color.new(42, 59, 83))
    footer_base = Color.new(245, 248, 252)
    footer_shadow = Color.new(19, 29, 43)
    pbDrawTextPositions(bitmap, [
      [PZHardcoreNuzlocke.t(:footer_left_right), 30, footer_y - 1, 0, footer_base, footer_shadow],
      [PZHardcoreNuzlocke.t(:footer_confirm), Graphics.width - 30, footer_y - 1, 1, footer_base, footer_shadow],
      [PZHardcoreNuzlocke.t(:footer_no), Graphics.width / 2, footer_y + 23, 2, footer_base, footer_shadow]
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
  def name; PZHardcoreNuzlocke.t(:challenges); end
  def values; [PZHardcoreNuzlocke.t(:open)]; end

  def get; 0; end
  def set(value); end
  def next(current); 0; end
  def prev(current); 0; end
end

class PZLanguageMenuOption
  def name; PZHardcoreNuzlocke.t(:language_option); end
  def values; PZHardcoreNuzlocke::I18n::LANGUAGE_NAMES; end
  def get; PZHardcoreNuzlocke.language_index; end
  def set(value)
    language = PZHardcoreNuzlocke::I18n::LANGUAGES[value.to_i] || :es
    PZHardcoreNuzlocke.set_language(language)
  end
  def next(current); (current.to_i + 1) % values.length; end
  def prev(current); (current.to_i - 1) % values.length; end
end
