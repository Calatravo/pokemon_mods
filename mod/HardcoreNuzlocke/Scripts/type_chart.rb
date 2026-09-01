# encoding: UTF-8

module PZHardcoreNuzlocke
  TYPE_ICON_PATH = "Graphics/Pictures/types_ico"
  TYPE_ICON_WIDTH = 24
  TYPE_ICON_HEIGHT = 28
  TYPE_ICON_COUNT = 19

  def self.type_chart_types
    result = []
    maximum = [PBTypes.maxValue, TYPE_ICON_COUNT - 1].min
    for type_id in 0..maximum
      begin
        next if PBTypes.isPseudoType?(type_id)
      rescue Exception
      end
      name = PBTypes.getName(type_id).to_s rescue ""
      next if name == "" || name == "???"
      result << type_id
    end
    result
  end

  def self.type_name(type_id)
    PBTypes.getName(type_id).to_s
  rescue Exception
    "Tipo #{type_id}"
  end

  def self.type_effectiveness(attack_type, defense_type)
    PBTypes.getEffectiveness(attack_type, defense_type)
  rescue Exception
    2
  end

  def self.open_type_chart
    scene = PZTypeChartScene.new
    scene.pbStartScene
    scene.pbMain
    scene.pbEndScene
    true
  ensure
    scene.pbEndScene if scene && !scene.ended?
  end
end

class PZTypeChartScene
  def initialize
    @ended = false
  end

  def ended?
    @ended
  end

  def pbStartScene
    @types = PZHardcoreNuzlocke.type_chart_types
    raise "No se encontraron tipos válidos" if @types.length == 0
    @type_index = 0
    @view = :defense
    @scroll_offset = 0
    @max_scroll = 0
    @done = false
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 999999
    @sprites = {}
    @sprites["background"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    background = @sprites["background"].bitmap
    background.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(23, 35, 55))
    background.fill_rect(12, 12, Graphics.width - 24, Graphics.height - 24, Color.new(42, 59, 83))
    background.fill_rect(18, 18, Graphics.width - 36, Graphics.height - 36, Color.new(224, 232, 240))
    @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
    @type_icons = AnimatedBitmap.new(PZHardcoreNuzlocke::TYPE_ICON_PATH)
    refresh
  end

  def pbMain
    loop do
      Graphics.update
      Input.update
      update
      break if @done
    end
  end

  def update
    changed = false
    if Input.trigger?(Input::RIGHT)
      @type_index += 1
      @type_index = 0 if @type_index >= @types.length
      @scroll_offset = 0
      changed = true
    elsif Input.trigger?(Input::LEFT)
      @type_index -= 1
      @type_index = @types.length - 1 if @type_index < 0
      @scroll_offset = 0
      changed = true
    elsif Input.trigger?(Input::C)
      @view = (@view == :defense) ? :attack : :defense
      @scroll_offset = 0
      changed = true
    elsif Input.repeat?(Input::UP) && @scroll_offset > 0
      @scroll_offset = [@scroll_offset - 36, 0].max
      changed = true
    elsif Input.repeat?(Input::DOWN) && @scroll_offset < @max_scroll
      @scroll_offset = [@scroll_offset + 36, @max_scroll].min
      changed = true
    elsif Input.trigger?(Input::B)
      @done = true
    end
    if changed
      pbPlayCursorSE() rescue nil
      refresh
    end
  end

  def refresh
    bitmap = @sprites["overlay"].bitmap
    bitmap.clear
    base = Color.new(40, 48, 64)
    shadow = Color.new(184, 192, 208)
    accent = Color.new(31, 91, 145)
    pbSetSystemFont(bitmap)
    pbDrawTextPositions(bitmap, [
      ["Tabla de tipos", 28, 22, 0, accent, shadow],
      [@view == :defense ? "DEFENSA" : "ATAQUE", Graphics.width - 28, 24, 1, accent, shadow]
    ])

    selected = @types[@type_index]
    bitmap.fill_rect(24, 62, Graphics.width - 48, 48, Color.new(207, 219, 232))
    draw_type_icon(bitmap, selected, 238, 72)
    pbDrawTextPositions(bitmap, [
      [PZHardcoreNuzlocke.type_name(selected), 272, 66, 0, base, shadow]
    ])

    if @view == :defense
      categories = [
        ["Débil frente a - recibe x2", 4, Color.new(190, 64, 64)],
        ["Resiste - recibe x1/2", 1, Color.new(48, 132, 86)],
        ["Inmune - recibe x0", 0, Color.new(91, 98, 112)]
      ]
      relation_proc = proc { |candidate| PZHardcoreNuzlocke.type_effectiveness(candidate, selected) }
    else
      categories = [
        ["Supereficaz contra - inflige x2", 4, Color.new(48, 132, 86)],
        ["Poco eficaz contra - inflige x1/2", 1, Color.new(190, 118, 42)],
        ["No afecta a - inflige x0", 0, Color.new(91, 98, 112)]
      ]
      relation_proc = proc { |candidate| PZHardcoreNuzlocke.type_effectiveness(selected, candidate) }
    end

    content = Bitmap.new(Graphics.width, 800)
    y = 0
    categories.each do |category|
      matching = @types.find_all { |candidate| relation_proc.call(candidate) == category[1] }
      y = draw_category(content, category[0], matching, y, category[2])
    end
    content_top = 116
    content_height = Graphics.height - content_top - 88
    @max_scroll = [y - content_height, 0].max
    @scroll_offset = @max_scroll if @scroll_offset > @max_scroll
    bitmap.fill_rect(24, content_top, Graphics.width - 48, content_height, Color.new(235, 240, 246))
    bitmap.blt(0, content_top, content, Rect.new(0, @scroll_offset, Graphics.width, content_height))
    content.dispose

    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [
      ["Izq./Der.: Tipo", 28, Graphics.height - 74, 0, base, shadow],
      ["C: Defensa/Ataque", Graphics.width / 2, Graphics.height - 74, 2, base, shadow],
      ["Arr./Ab.: Lista", Graphics.width - 28, Graphics.height - 74, 1, base, shadow]
    ])
    note = "X/Esc: Volver. Daño x1 si no aparece."
    pbDrawTextPositions(bitmap, [[note, Graphics.width / 2, Graphics.height - 50, 2, Color.new(75, 82, 96), shadow]])
  end

  def draw_category(bitmap, label, type_ids, y, color)
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [[label, 28, y, 0, color, Color.new(210, 216, 224)]])
    y += 26
    if type_ids.length == 0
      pbDrawTextPositions(bitmap, [["Ninguno", 36, y, 0, Color.new(90, 96, 108), Color.new(220, 224, 230)]])
      return y + 32
    end
    columns = 3
    gap = 6
    chip_width = (Graphics.width - 56 - gap * 2) / columns
    type_ids.each_with_index do |type_id, index|
      column = index % columns
      row = index / columns
      draw_type_chip(bitmap, type_id, 28 + column * (chip_width + gap), y + row * 31, chip_width, color)
    end
    rows = (type_ids.length + columns - 1) / columns
    y + rows * 31 + 6
  end

  def draw_type_chip(bitmap, type_id, x, y, width, color)
    bitmap.fill_rect(x, y, width, 28, Color.new(235, 239, 244))
    bitmap.fill_rect(x, y, 4, 28, color)
    draw_type_icon(bitmap, type_id, x + 8, y)
    pbDrawTextPositions(bitmap, [[PZHardcoreNuzlocke.type_name(type_id), x + 38, y - 1, 0, Color.new(45, 52, 66), Color.new(210, 216, 224)]])
  end

  def draw_type_icon(bitmap, type_id, x, y)
    source = Rect.new(0, type_id * PZHardcoreNuzlocke::TYPE_ICON_HEIGHT,
      PZHardcoreNuzlocke::TYPE_ICON_WIDTH, PZHardcoreNuzlocke::TYPE_ICON_HEIGHT)
    bitmap.blt(x, y, @type_icons.bitmap, source)
  end

  def pbEndScene
    return if @ended
    @ended = true
    @type_icons.dispose if @type_icons
    pbDisposeSpriteHash(@sprites) if @sprites
    @viewport.dispose if @viewport && !@viewport.disposed?
  end
end

class PZTypeChartMenuOption
  attr_reader :values
  attr_reader :name

  def initialize
    @name = _INTL("Tabla de tipos")
    @values = [_INTL("Abrir")]
  end

  def get; 0; end
  def set(value); end
  def next(current); 0; end
  def prev(current); 0; end
end
