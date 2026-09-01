# encoding: UTF-8

module PZHardcoreNuzlocke
  TEST_INPUT_FILE = File.join(PZ_HARDCORE_NUZLOCKE_ROOT, "test-input.txt")
  TEST_INPUT_ACK = File.join(PZ_HARDCORE_NUZLOCKE_ROOT, "test-input.ack")

  def self.test_control_enabled?
    ENV["PZN_TEST_CONTROL"].to_s == "1"
  end

  def self.test_key_code(name)
    keys = {
      "DOWN"=>Input::DOWN, "LEFT"=>Input::LEFT, "RIGHT"=>Input::RIGHT, "UP"=>Input::UP,
      "A"=>Input::A, "B"=>Input::B, "C"=>Input::C,
      "L"=>Input::L, "R"=>Input::R, "X"=>Input::X, "Y"=>Input::Y, "Z"=>Input::Z,
      "ENTER"=>Input::C, "RETURN"=>Input::C, "CONFIRM"=>Input::C,
      "ESC"=>Input::B, "ESCAPE"=>Input::B, "CANCEL"=>Input::B
    }
    keys[name.to_s.upcase]
  end

  def self.test_ex_key_codes(name)
    keys = {
      "DOWN"=>[:DOWN, 0x28], "LEFT"=>[:LEFT, 0x25],
      "RIGHT"=>[:RIGHT, 0x27], "UP"=>[:UP, 0x26],
      "ENTER"=>[:RETURN, 13], "RETURN"=>[:RETURN, 13],
      "CONFIRM"=>[:RETURN, 13], "ESC"=>[:ESCAPE, 0x1B],
      "ESCAPE"=>[:ESCAPE, 0x1B], "CANCEL"=>[:ESCAPE, 0x1B],
      "BACKSPACE"=>[:BACKSPACE, 8], "DELETE"=>[:DELETE, 0x2E]
    }
    keys[name.to_s.upcase] || []
  end

  def self.test_scene_name
    return $scene.class.to_s if defined?($scene) && $scene
    "sin escena"
  rescue Exception
    "desconocida"
  end

  def self.write_test_ack(message)
    return if !test_control_enabled?
    File.open(TEST_INPUT_ACK, "wb") do |file|
      file.write("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n")
      file.write("scene=#{test_scene_name}\n")
      file.write("#{message}\n")
    end
  rescue Exception => error
    log("test input ack error: #{error.class}: #{error.message}")
  end

  def self.test_control_ready!
    return if !test_control_enabled? || @test_control_ready
    @test_control_ready = true
    @test_input_frame = 0
    @test_input_queue = []
    @test_active_keys = []
    @test_active_ex_keys = []
    @test_active_text = nil
    @test_text_consumed = false
    @test_pending_actions = []
    write_test_ack("ready=1")
    log("Interactive test input bridge READY")
  end

  def self.poll_test_input_file
    return if !test_control_enabled?
    test_control_ready!
    return if !File.exist?(TEST_INPUT_FILE)
    lines = File.readlines(TEST_INPUT_FILE)
    File.delete(TEST_INPUT_FILE) rescue nil
    delay = 0
    accepted = []
    rejected = []
    lines.each do |raw_line|
      line = raw_line.to_s.strip
      next if line == "" || line[0, 1] == "#"
      if line =~ /^WAIT\s+(\d+)$/i
        delay += $1.to_i
        accepted << "WAIT #{delay}"
        next
      end
      if line =~ /^TEXT\s+(.+)$/i
        value = $1.to_s
        @test_input_queue << [@test_input_frame.to_i + delay + 1, nil,
                              "TEXT #{value}", [], value]
        accepted << "TEXT #{value}"
        delay += 1
        next
      end
      if line =~ /^HOLD\s+(DOWN|LEFT|RIGHT|UP)\s+(\d+)$/i
        name = $1.to_s.upcase
        frames = [$2.to_i, 1].max
        key = test_key_code(name)
        ex_keys = test_ex_key_codes(name)
        frames.times do |index|
          label = index == 0 ? "HOLD #{name} #{frames}" : nil
          @test_input_queue << [@test_input_frame.to_i + delay + index + 1,
                                key, label, ex_keys, nil]
        end
        accepted << "HOLD #{name} #{frames}"
        delay += frames
        next
      end
      if line =~ /^OPEN\s+(TYPE_CHART|CHALLENGES|RANDOM|NUZLOCKE|LEARNING|MOVE_INFO|ITEM_PICKUP|ITEM_RECEIVE|ENCOUNTER_TEST|OPTIONS|PAUSE|INITIAL_FLOW|BATTLE)$/i
        action = $1.to_s.upcase
        @test_pending_actions << action
        accepted << "OPEN #{action}"
        next
      end
      key = test_key_code(line)
      ex_keys = test_ex_key_codes(line)
      if key || ex_keys.length > 0
        @test_input_queue << [@test_input_frame.to_i + delay + 1, key,
                              line.upcase, ex_keys, nil]
        accepted << line.upcase
        delay += 1
      else
        rejected << line
      end
    end
    message = "accepted=#{accepted.join(',')}"
    message += "\nrejected=#{rejected.join(',')}" if rejected.length > 0
    message += "\nqueued=#{@test_input_queue.length}"
    write_test_ack(message)
    summary = message.gsub("\n", "; ")
    log("Test input received: #{summary}")
  rescue Exception => error
    log_exception("test input poll error", error)
    write_test_ack("error=#{error.class}: #{error.message}")
  end

  def self.advance_test_input
    return if !test_control_enabled?
    poll_test_input_file
    @test_input_frame = @test_input_frame.to_i + 1
    @test_active_keys = []
    @test_active_ex_keys = []
    @test_active_text = nil
    @test_text_consumed = false
    delivered = []
    while @test_input_queue && @test_input_queue[0] && @test_input_queue[0][0] <= @test_input_frame
      entry = @test_input_queue.shift
      @test_active_keys << entry[1] if entry[1]
      @test_active_ex_keys.concat(entry[3] || [])
      @test_active_text = entry[4] if entry[4]
      delivered << entry[2]
    end
    if delivered.length > 0
      write_test_ack("delivered=#{delivered.join(',')}\nqueued=#{@test_input_queue.length}")
      log("Test input delivered: #{delivered.join(',')} (scene #{test_scene_name})")
    end
  end

  def self.test_key_active?(key)
    test_control_enabled? && @test_active_keys && @test_active_keys.include?(key)
  end

  def self.test_direction
    return 0 if !test_control_enabled?
    return 2 if test_key_active?(Input::DOWN)
    return 4 if test_key_active?(Input::LEFT)
    return 6 if test_key_active?(Input::RIGHT)
    return 8 if test_key_active?(Input::UP)
    0
  end

  def self.test_ex_key_active?(key)
    test_control_enabled? && @test_active_ex_keys && @test_active_ex_keys.include?(key)
  end

  def self.consume_test_text
    return nil if !test_control_enabled? || !@test_active_text || @test_text_consumed
    @test_text_consumed = true
    @test_active_text
  end

  def self.process_test_action
    return if !test_control_enabled? || @test_action_running
    return if !@test_pending_actions || @test_pending_actions.length == 0
    action = @test_pending_actions.shift
    @test_action_running = true
    write_test_ack("action=#{action}\nstatus=opening")
    log("Test action opening: #{action}")
    begin
      case action
      when "TYPE_CHART"
        safe_ui("#{t(:type_chart)} [test]") { open_type_chart }
      when "CHALLENGES"
        safe_ui("#{t(:challenges)} [test]") { open_menu }
      when "RANDOM"
        safe_ui("Random [prueba]") { open_random_setup(false) }
      when "NUZLOCKE"
        safe_ui("Nuzlocke [prueba]") { open_nuzlocke_setup(false) }
      when "LEARNING"
        safe_ui("#{t(:learning_option)} [test]") { open_learning_setup }
      when "MOVE_INFO"
        safe_ui("#{t(:move_info_title)} [test]") { open_move_info_by_id(test_move_id) }
      when "ITEM_PICKUP"
        item = hasConst?(PBItems, :ANTIDOTE) ? getConst(PBItems, :ANTIDOTE) : 1
        safe_ui("Item pickup [test]") { Kernel.pbItemBall(item, 1) }
      when "ITEM_RECEIVE"
        item = hasConst?(PBItems, :POTION) ? getConst(PBItems, :POTION) : 1
        safe_ui("Item receipt [test]") { Kernel.pbReceiveItem(item, 1) }
      when "ENCOUNTER_TEST"
        static_type = random_encounter_type
        step_type = nil
        with_step_encounter { step_type = random_encounter_type }
        if static_type || !step_type
          raise "classification mismatch: static=#{static_type.inspect}, step=#{step_type.inspect}"
        end
        log("Encounter classification test PASS: static=nil, step=#{step_type}")
      when "OPTIONS"
        safe_ui("Opciones [prueba]") do
          scene = PokemonOptionScene.new
          screen = PokemonOption.new(scene)
          screen.pbStartScreen
        end
      when "PAUSE"
        safe_ui("Pause menu [test]") { DP_PauseMenu.new }
      when "INITIAL_FLOW"
        current = state
        if !current || !defined?($PokemonGlobal) || !$PokemonGlobal
          show_info(t(:test_requires_save), t(:test_initial_title))
        else
          saved_state = Marshal.dump(current)
          saved_nuzlocke = $PokemonGlobal.instance_variable_get(:@nuzlocke)
          saved_random_switch = (defined?($game_switches) && $game_switches) ? $game_switches[409] : nil
          begin
            current[:first_run_setup_done] = false
            current[:activated] = false
            current[:locked] = false
            current[:random] = default_random_state
            $game_switches[409] = false if defined?($game_switches) && $game_switches
            set_base_nuzlocke(false)
            safe_ui("#{t(:initial_config_title)} [test]") { open_post_nuzlocke_first_run_setup }
          ensure
            $PokemonGlobal.pzn_hardcore_state = Marshal.load(saved_state)
            $game_switches[409] = saved_random_switch if defined?($game_switches) && $game_switches && !saved_random_switch.nil?
            set_base_nuzlocke(saved_nuzlocke)
          end
        end
      when "BATTLE"
        species = hasConst?(PBSpecies, :RATTATA) ? getConst(PBSpecies, :RATTATA) : 1
        safe_ui("Combate salvaje [prueba]") do
          temporary = nil
          if $Trainer.party.length == 0
            test_species = hasConst?(PBSpecies, :VANILLITE) ? getConst(PBSpecies, :VANILLITE) : species
            temporary = PokeBattle_Pokemon.new(test_species, 5, $Trainer)
            $Trainer.party << temporary
          end
          begin
            host = Object.new
            wild = call_global(:pbGenerateWildPokemon, species, 2)
            Events.onStartBattle.trigger(nil, wild)
            scene = call_global(:pbNewBattleScene)
            battle = PokeBattle_Battle.new(scene, $Trainer.party, [wild], $Trainer, nil, false)
            battle.internalbattle = true
            battle.cantescape = false
            call_global(:pbPrepareBattle, battle)
            decision = 0
            host.send(:pbBattleAnimation, host.send(:pbGetWildBattleBGM, species)) do
              host.send(:pbSceneStandby) do
                decision = battle.pbStartBattle(true)
              end
            end
            Events.onEndBattle.trigger(nil, decision, true)
            Events.onWildBattleEnd.trigger(nil, species, 2, decision)
            log("Direct constructed test battle decision: #{decision}")
            decision != 2
          ensure
            $Trainer.party.delete(temporary) if temporary
          end
        end
      end
      write_test_ack("action=#{action}\nstatus=closed")
      log("Test action closed: #{action}")
    rescue Exception => error
      log_exception("Test action error [#{action}]", error)
      write_test_ack("action=#{action}\nstatus=error\nerror=#{error.class}: #{error.message}")
    ensure
      @test_action_running = false
    end
  end

  def self.install_test_input_hook
    return if Input.respond_to?(:pzn_test_original_update)
    class << Input
      alias_method :pzn_test_original_update, :update
      alias_method :pzn_test_original_trigger, :trigger?
      alias_method :pzn_test_original_repeat, :repeat?
      alias_method :pzn_test_original_press, :press?
      alias_method :pzn_test_original_dir4, :dir4 if method_defined?(:dir4)
      alias_method :pzn_test_original_dir8, :dir8 if method_defined?(:dir8)
      alias_method :pzn_test_original_triggerex, :triggerex? if method_defined?(:triggerex?)
      alias_method :pzn_test_original_repeatex, :repeatex? if method_defined?(:repeatex?)
      alias_method :pzn_test_original_pressex, :pressex? if method_defined?(:pressex?)
      alias_method :pzn_test_original_gets, :gets if method_defined?(:gets)

      def update
        pzn_test_original_update
        PZHardcoreNuzlocke.advance_test_input
      end

      def trigger?(key)
        return true if PZHardcoreNuzlocke.test_key_active?(key)
        pzn_test_original_trigger(key)
      end

      def repeat?(key)
        return true if PZHardcoreNuzlocke.test_key_active?(key)
        pzn_test_original_repeat(key)
      end

      def press?(key)
        return true if PZHardcoreNuzlocke.test_key_active?(key)
        pzn_test_original_press(key)
      end

      if method_defined?(:pzn_test_original_dir4)
        def dir4
          virtual = PZHardcoreNuzlocke.test_direction
          return virtual if virtual != 0
          pzn_test_original_dir4
        end
      end

      if method_defined?(:pzn_test_original_dir8)
        def dir8
          virtual = PZHardcoreNuzlocke.test_direction
          return virtual if virtual != 0
          pzn_test_original_dir8
        end
      end

      if method_defined?(:pzn_test_original_triggerex)
        def triggerex?(key)
          return true if PZHardcoreNuzlocke.test_ex_key_active?(key)
          pzn_test_original_triggerex(key)
        end
      end

      if method_defined?(:pzn_test_original_repeatex)
        def repeatex?(key)
          return true if PZHardcoreNuzlocke.test_ex_key_active?(key)
          pzn_test_original_repeatex(key)
        end
      end

      if method_defined?(:pzn_test_original_pressex)
        def pressex?(key)
          return true if PZHardcoreNuzlocke.test_ex_key_active?(key)
          pzn_test_original_pressex(key)
        end
      end

      if method_defined?(:pzn_test_original_gets)
        def gets
          original = pzn_test_original_gets
          virtual = PZHardcoreNuzlocke.consume_test_text
          return original if !virtual
          original.to_s + virtual.to_s
        end
      end
    end
    test_control_ready!
  end
end
