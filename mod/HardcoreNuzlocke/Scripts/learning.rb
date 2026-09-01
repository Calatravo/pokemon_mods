# encoding: UTF-8

module PZHardcoreNuzlocke
  LEARNING_SETTINGS = [
    [:move_info, :learning_move_info, :learning_move_info_help],
    [:move_effectiveness, :learning_effectiveness, :learning_effectiveness_help],
    [:exact_multipliers, :learning_exact, :learning_exact_help],
    [:switch_matchup, :learning_switch, :learning_switch_help],
    [:warn_no_effect, :learning_warn, :learning_warn_help],
    [:show_enemy_types, :learning_enemy_types, :learning_enemy_types_help]
  ]

  LEARNING_DEFAULTS = {
    :move_info=>true,
    :move_effectiveness=>true,
    :exact_multipliers=>false,
    :switch_matchup=>true,
    :warn_no_effect=>true,
    :show_enemy_types=>true
  }

  class << self
    attr_accessor :learning_switch_context
  end

  def self.learning_setting?(key)
    return LEARNING_DEFAULTS[key] if !defined?($PokemonSystem) || !$PokemonSystem
    value = $PokemonSystem.instance_variable_get("@pzn_learning_#{key}")
    value.nil? ? LEARNING_DEFAULTS[key] : !!value
  end

  def self.set_learning_setting(key, value)
    return false if !defined?($PokemonSystem) || !$PokemonSystem
    $PokemonSystem.instance_variable_set("@pzn_learning_#{key}", !!value)
    true
  end

  def self.open_learning_setup
    return false if !defined?($PokemonSystem) || !$PokemonSystem
    loop do
      commands = LEARNING_SETTINGS.collect do |entry|
        "[#{learning_setting?(entry[0]) ? 'X' : ' '}] #{t(entry[1])}"
      end
      commands << t(:apply_back)
      choice = choose(t(:learning_title), commands)
      return true if choice < 0 || choice == LEARNING_SETTINGS.length
      entry = LEARNING_SETTINGS[choice]
      if confirm_toggle(t(entry[1]), t(entry[2]), learning_setting?(entry[0]))
        set_learning_setting(entry[0], !learning_setting?(entry[0]))
      end
    end
  end

  def self.creature_types(creature)
    return [] if !creature
    type1 = creature.type1 rescue nil
    type2 = creature.type2 rescue type1
    result = []
    result << type1 if !type1.nil?
    result << type2 if !type2.nil? && type2 != type1
    result
  rescue Exception
    []
  end

  def self.combined_type_modifier(attack_type, defender)
    types = creature_types(defender)
    return 4 if types.length == 0
    first = type_effectiveness(attack_type, types[0])
    second = types.length > 1 ? type_effectiveness(attack_type, types[1]) : 2
    first.to_i * second.to_i
  rescue Exception
    4
  end

  def self.multiplier_text(modifier)
    case modifier.to_i
    when 0 then "x0"
    when 1 then "x0.25"
    when 2 then "x0.5"
    when 4 then "x1"
    when 8 then "x2"
    else "x#{modifier.to_i / 4}"
    end
  end

  def self.effectiveness_label(modifier)
    return t(:effect_none) if modifier.to_i == 0
    return t(:effect_super) if modifier.to_i > 4
    return t(:effect_low) if modifier.to_i < 4
    t(:effect_normal)
  end

  def self.opposing_battlers(attacker)
    return [] if !attacker
    battle = attacker.instance_variable_get(:@battle) rescue nil
    battle = attacker.battle if !battle && attacker.respond_to?(:battle)
    return [] if !battle || !battle.respond_to?(:battlers)
    battle.battlers.find_all do |candidate|
      candidate && !candidate.isFainted? && attacker.pbIsOpposing?(candidate.index)
    end
  rescue Exception
    []
  end

  def self.primary_opponent(attacker)
    opposing_battlers(attacker)[0]
  end

  def self.move_modifier(move, attacker, target=nil)
    target = primary_opponent(attacker) if !target
    return 4 if !move || !target
    combined_type_modifier(move.type, target)
  rescue Exception
    4
  end

  def self.move_label(move, attacker)
    modifier = move_modifier(move, attacker)
    return multiplier_text(modifier) if learning_setting?(:exact_multipliers)
    effectiveness_label(modifier)
  end

  def self.type_names(creature)
    names = creature_types(creature).collect { |type_id| type_name(type_id) }
    names.length == 0 ? t(:unknown) : names.join("/")
  end

  def self.enhance_fight_buttons(bitmap, moves, attacker)
    return if !bitmap || !moves || !attacker
    pbSetSmallFont(bitmap)
    help_parts = []
    help_parts << t(:fight_info_hint) if learning_setting?(:move_info)
    if learning_setting?(:show_enemy_types)
      opponent = primary_opponent(attacker)
      help_parts << t(:opponent_types, type_names(opponent)) if opponent
    end
    if help_parts.length > 0
      pbDrawTextPositions(bitmap, [[help_parts.join("  "), 8, 7, 0,
        Color.new(245, 248, 252), Color.new(35, 45, 60)]])
    end
    return if !learning_setting?(:move_effectiveness)
    moves.each_with_index do |move, index|
      next if !move || move.id == 0
      x = (index % 2) == 0 ? 4 : 192
      y = ((index / 2) == 0 ? 6 : 48) + FightMenuButtons::UPPERGAP
      if move.basedamage.to_i <= 0
        label = t(:effect_status)
        base = Color.new(100, 106, 118)
      else
        modifier = move_modifier(move, attacker)
        label = learning_setting?(:exact_multipliers) ? multiplier_text(modifier) : effectiveness_label(modifier)
        base = modifier == 0 ? Color.new(100, 106, 118) :
          (modifier > 4 ? Color.new(32, 142, 76) :
          (modifier < 4 ? Color.new(188, 104, 32) : Color.new(48, 92, 145)))
      end
      pbDrawTextPositions(bitmap, [[label, x + 184, y + 23, 1,
        base, Color.new(238, 242, 247)]])
    end
  rescue Exception => error
    log("fight help draw error: #{error.class}: #{error.message}")
  end

  def self.switch_matchup_text(pokemon, context)
    return t(:choose_pokemon) if !pokemon || !context
    battle = context[:battle]
    battler_index = context[:battler_index]
    attacker = battle && battle.battlers ? battle.battlers[battler_index] : nil
    rivals = opposing_battlers(attacker)
    rival = rivals[0]
    return t(:choose_pokemon) if !rival

    candidate_types = creature_types(pokemon)
    rival_types = creature_types(rival)
    offense = 0
    candidate_types.each do |attack_type|
      modifier = combined_type_modifier(attack_type, rival)
      offense = modifier if modifier > offense
    end
    offense = 4 if offense == 0 && candidate_types.length == 0
    defense = 0
    rival_types.each do |attack_type|
      modifier = combined_type_modifier(attack_type, pokemon)
      defense = modifier if modifier > defense
    end
    defense = 4 if defense == 0 && rival_types.length == 0

    if learning_setting?(:exact_multipliers)
      t(:switch_exact, rival.name, multiplier_text(offense), multiplier_text(defense))
    else
      offense_text = offense > 4 ? t(:attack_effective) : (offense < 4 ? t(:attack_weak) : t(:attack_neutral))
      defense_text = defense > 4 ? t(:defense_weak) : (defense < 4 ? t(:defense_resists) : t(:defense_neutral))
      t(:switch_words, rival.name, offense_text, defense_text)
    end
  rescue Exception => error
    log("switch matchup error: #{error.class}: #{error.message}")
    t(:choose_pokemon)
  end

  def self.refresh_switch_help(scene)
    return if !learning_setting?(:switch_matchup) || !learning_switch_context
    party = scene.instance_variable_get(:@party) rescue nil
    sprites = scene.instance_variable_get(:@sprites) rescue nil
    index = scene.instance_variable_get(:@activecmd) rescue nil
    if (!index || index < 0) && sprites
      chooser = sprites["pokemon"] rescue nil
      index = chooser.index if chooser && chooser.respond_to?(:index)
    end
    if (!index || index < 0) && sprites && party
      party.length.times do |candidate|
        panel = sprites["pokemon#{candidate}"] rescue nil
        next if !panel
        selected = panel.respond_to?(:selected) ? panel.selected : nil
        selected = (panel.instance_variable_get(:@selected) rescue nil) if selected.nil?
        if selected
          index = candidate
          break
        end
      end
    end
    index = -1 if !index
    return if !party || index < 0
    pokemon = index < party.length ? party[index] : nil
    text = pokemon ? switch_matchup_text(pokemon, learning_switch_context) : t(:footer_back)
    helpwindow = scene.instance_variable_get(:@sprites)["helpwindow"] rescue nil
    return if !helpwindow
    current = helpwindow.respond_to?(:text) ? helpwindow.text : nil
    return if current == text
    helpwindow.text = text
    helpwindow.visible = true
  rescue Exception => error
    log("switch help refresh error: #{error.class}: #{error.message}")
  end

  def self.move_description(move_id)
    pbGetMessage(MessageTypes::MoveDescriptions, move_id).to_s
  rescue Exception
    t(:move_no_description)
  end

  def self.open_move_info(move, attacker=nil)
    scene = PZMoveInfoScene.new(move, attacker)
    scene.start
    scene.main
    scene.finish
    true
  ensure
    scene.finish if scene
  end

  def self.open_move_info_by_id(move_id)
    open_move_info(PZMoveInfoData.new(move_id), nil)
  end

  def self.test_move_id
    return getConst(PBMoves, :ROCKSLIDE) if hasConst?(PBMoves, :ROCKSLIDE)
    return getConst(PBMoves, :TACKLE) if hasConst?(PBMoves, :TACKLE)
    1
  end
end

class PZMoveInfoData
  attr_reader :id, :name, :type, :basedamage, :accuracy, :priority, :totalpp, :category
  attr_accessor :pp

  def initialize(move_id)
    @id = move_id
    data = PBMoveData.new(move_id)
    @name = PBMoves.getName(move_id)
    @type = data.type
    @basedamage = data.basedamage
    @accuracy = data.accuracy
    @priority = data.priority
    @totalpp = data.totalpp
    @pp = @totalpp
    @category = data.category
  end

  def pbIsStatus?; @category == 2; end
  def pbIsPhysical?(type=nil); @category == 0; end
  def pbIsSpecial?(type=nil); @category == 1; end
end

class PZMoveInfoScene
  def initialize(move, attacker=nil)
    @move = move
    @attacker = attacker
    @ended = false
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
    @type_icons = AnimatedBitmap.new(PZHardcoreNuzlocke::TYPE_ICON_PATH)
    refresh
  end

  def main
    loop do
      Graphics.update
      Input.update
      break if Input.trigger?(Input::B) || Input.trigger?(Input::C) || Input.trigger?(Input::X)
    end
    pbPlayCancelSE() rescue nil
  end

  def category_name
    category = @move.instance_variable_get(:@category) rescue nil
    category = @move.category if category.nil? && @move.respond_to?(:category)
    return PZHardcoreNuzlocke.t(:move_physical) if category == 0
    return PZHardcoreNuzlocke.t(:move_special) if category == 1
    PZHardcoreNuzlocke.t(:move_status)
  end

  def wrap_text(text, width=47)
    lines = []
    text.to_s.split(/\n/, -1).each do |paragraph|
      current = ""
      paragraph.split(/\s+/).each do |word|
        candidate = current.length == 0 ? word : current + " " + word
        if current.length > 0 && candidate.length > width
          lines << current
          current = word
        else
          current = candidate
        end
      end
      lines << current if current.length > 0
    end
    lines
  end

  def refresh
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base = Color.new(40, 48, 64)
    shadow = Color.new(184, 192, 208)
    accent = Color.new(31, 91, 145)
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [[@move.name, 30, 22, 0, accent, shadow]])

    bitmap.fill_rect(26, 62, Graphics.width - 52, 44, Color.new(207, 219, 232))
    source = Rect.new(0, @move.type * PZHardcoreNuzlocke::TYPE_ICON_HEIGHT,
      PZHardcoreNuzlocke::TYPE_ICON_WIDTH, PZHardcoreNuzlocke::TYPE_ICON_HEIGHT)
    bitmap.blt(38, 70, @type_icons.bitmap, source)
    pbDrawTextPositions(bitmap, [
      [PZHardcoreNuzlocke.type_name(@move.type), 70, 67, 0, base, shadow],
      [category_name, Graphics.width - 38, 67, 1, base, shadow]
    ])

    power = @move.basedamage.to_i > 0 ? @move.basedamage.to_i.to_s : "---"
    accuracy = @move.accuracy.to_i > 0 ? "#{@move.accuracy}%" : "---"
    pp = @move.respond_to?(:pp) ? "#{@move.pp}/#{@move.totalpp}" : @move.totalpp.to_s
    priority = @move.priority.to_i >= 0 ? "+#{@move.priority}" : @move.priority.to_s
    bitmap.fill_rect(26, 112, Graphics.width - 52, 68, Color.new(235, 240, 246))
    pbDrawTextPositions(bitmap, [
      [PZHardcoreNuzlocke.t(:move_power, power), 38, 116, 0, base, shadow],
      [PZHardcoreNuzlocke.t(:move_accuracy, accuracy), 190, 116, 0, base, shadow],
      [PZHardcoreNuzlocke.t(:move_pp, pp), 370, 116, 0, base, shadow],
      [PZHardcoreNuzlocke.t(:move_priority, priority), 38, 146, 0, base, shadow]
    ])
    if @attacker
      target = PZHardcoreNuzlocke.primary_opponent(@attacker)
      if target
        if @move.basedamage.to_i <= 0
          effect = PZHardcoreNuzlocke.t(:move_status_effect)
        else
          modifier = PZHardcoreNuzlocke.move_modifier(@move, @attacker, target)
          effect = PZHardcoreNuzlocke.t(:move_against, target.name, PZHardcoreNuzlocke.effectiveness_label(modifier), PZHardcoreNuzlocke.multiplier_text(modifier))
        end
        pbDrawTextPositions(bitmap, [[effect, Graphics.width - 38, 146, 1, accent, shadow]])
      end
    end

    bitmap.fill_rect(26, 188, Graphics.width - 52, 132, Color.new(235, 240, 246))
    pbDrawTextPositions(bitmap, [[PZHardcoreNuzlocke.t(:move_description), 38, 190, 0, accent, shadow]])
    description = PZHardcoreNuzlocke.move_description(@move.id)
    wrap_text(description).first(4).each_with_index do |line, index|
      pbDrawTextPositions(bitmap, [[line, 38, 220 + index * 24, 0, base, shadow]])
    end

    footer_y = Graphics.height - 48
    bitmap.fill_rect(18, footer_y, Graphics.width - 36, 30, Color.new(42, 59, 83))
    pbDrawTextPositions(bitmap, [[PZHardcoreNuzlocke.t(:move_footer), Graphics.width / 2,
      footer_y - 1, 2, Color.new(245, 248, 252), Color.new(19, 29, 43)]])
  end

  def finish
    return if @ended
    @ended = true
    @type_icons.dispose if @type_icons
    pbDisposeSpriteHash(@sprites) if @sprites
    @viewport.dispose if @viewport && !@viewport.disposed?
  end
end

class PZLearningMenuOption
  def name; PZHardcoreNuzlocke.t(:learning_option); end
  def values; [PZHardcoreNuzlocke.t(:configure)]; end

  def get; 0; end
  def set(value); end
  def next(current); 0; end
  def prev(current); 0; end
end
