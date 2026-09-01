# encoding: UTF-8

module PZHardcoreNuzlocke
  def self.install_ready?
    defined?(PokemonGlobalMetadata) && defined?(PokeBattle_Pokemon) &&
      defined?(PokeBattle_Battle) && defined?(PokeBattle_BattleCommon) &&
      defined?(PokeBattle_SafariZone) && defined?(PokeBattle_Scene) &&
      defined?(PokemonStorage) && defined?(PokemonStorageScreen) &&
      defined?(PokemonOptionScene) && defined?(Window_PokemonOption) &&
      defined?(DP_PauseMenu) && defined?(Scene_Map) &&
      defined?(FightMenuDisplay) && defined?(FightMenuButtons) &&
      defined?(PokemonScreen_Scene)
  end

  def self.final_install_ready?
    install_ready? && defined?(Scene_DebugIntro) &&
      (Object.private_method_defined?(:enable_random) || Object.method_defined?(:enable_random)) &&
      (Object.private_method_defined?(:pbAddPokemon) || Object.method_defined?(:pbAddPokemon))
  end

  def self.report_not_ready_once
    return if @reported_not_ready
    @reported_not_ready = true
    names = [:PokemonGlobalMetadata, :PokeBattle_Pokemon, :PokeBattle_Battle,
             :PokeBattle_BattleCommon, :PokeBattle_SafariZone, :PokeBattle_Scene,
             :PokemonStorage, :PokemonStorageScreen, :PokemonOptionScene,
             :Window_PokemonOption, :DP_PauseMenu, :Scene_Map,
             :FightMenuDisplay, :FightMenuButtons, :PokemonScreen_Scene]
    missing = names.find_all { |name| !Object.const_defined?(name) }
    log("Install not ready; missing constants: #{missing.join(', ')}")
  end

  def self.schedule_install!
    return if @bridge_scheduled
    return if !defined?($RGSS_SCRIPTS) || !$RGSS_SCRIPTS
    @bridge_scheduled = true
    existing_bridge = $RGSS_SCRIPTS.any? { |entry| entry[1].to_s == "PZ Hardcore Nuzlocke Bridge" }
    if existing_bridge
      log("Persistent runtime bridge found")
      return
    end
    main_index = $RGSS_SCRIPTS.length
    ($RGSS_SCRIPTS.length - 1).downto(0) do |index|
      name = $RGSS_SCRIPTS[index][1].to_s.downcase
      if name == "main" || name =~ /(^|_)main$/
        main_index = index
        break
      end
    end
    bridge = <<'PZ_BRIDGE'
if PZHardcoreNuzlocke.install_ready?
  PZHardcoreNuzlocke.install!
  PZHardcoreNuzlocke.install_runtime_update_hook! if PZHardcoreNuzlocke.installed
else
  PZHardcoreNuzlocke.report_not_ready_once
end
PZ_BRIDGE
    compressed = Zlib::Deflate.deflate(bridge)
    $RGSS_SCRIPTS.insert(main_index, [990001, "PZ Hardcore Nuzlocke Bridge", compressed])
    log("Runtime bridge inserted before script index #{main_index}")
  end

  def self.install_runtime_update_hook!
    return if Graphics.respond_to?(:pzn_hardcore_runtime_update)
    class << Graphics
      alias_method :pzn_hardcore_runtime_update, :update
      def update
        pzn_hardcore_runtime_update
        PZHardcoreNuzlocke.tick if PZHardcoreNuzlocke.installed
      end
    end
    validate_installation!
  end

  def self.validate_installation!
    checks = {
      :pokemon_hp=>PokeBattle_Pokemon.method_defined?(:pzn_hardcore_original_hp_set),
      :capture=>PokeBattle_BattleCommon.method_defined?(:pzn_hardcore_original_throw_ball),
      :battle=>PokeBattle_Battle.method_defined?(:pzn_hardcore_original_start_core),
      :storage=>PokemonStorageScreen.method_defined?(:pzn_hardcore_original_withdraw),
      :options=>PokemonOptionScene.method_defined?(:pzn_hardcore_original_add_on_options),
      :type_chart=>defined?(PZTypeChartScene) && defined?(PZTypeChartMenuOption) &&
                   !!(pbResolveBitmap(PZHardcoreNuzlocke::TYPE_ICON_PATH) rescue nil),
      :pause=>DP_PauseMenu.method_defined?(:pzn_hardcore_original_pause_update) &&
              DP_PauseMenu.method_defined?(:pzn_hardcore_original_pause_main) &&
              respond_to?(:add_pause_menu_option),
      :first_run=>Scene_Map.method_defined?(:pzn_hardcore_original_transfer_player) &&
                  Scene_Map.method_defined?(:pzn_hardcore_original_first_run_update),
      :learning=>PokeBattle_Scene.method_defined?(:pzn_learning_original_fight_menu) &&
                 PokeBattle_Scene.method_defined?(:pzn_learning_original_switch) &&
                 FightMenuButtons.method_defined?(:pzn_learning_original_refresh) &&
                 PokemonScreen_Scene.method_defined?(:pzn_learning_original_update),
      :gifts=>(Object.private_method_defined?(:pzn_hardcore_original_add_pokemon) || Object.method_defined?(:pzn_hardcore_original_add_pokemon)),
      :test_input=>Input.respond_to?(:pzn_test_original_update) &&
                   Input.respond_to?(:pzn_test_original_triggerex) &&
                   Input.respond_to?(:pzn_test_original_gets),
      :runtime=>Graphics.respond_to?(:pzn_hardcore_runtime_update)
    }
    failed = checks.find_all { |key, value| !value }.collect { |entry| entry[0] }
    if failed.length == 0
      log("Installation self-test PASS (#{checks.length} hooks)")
    else
      log("Installation self-test FAIL: #{failed.join(', ')}")
    end
  rescue Exception => error
    log("Installation self-test ERROR: #{error.class}: #{error.message}")
  end

  def self.install!
    return if installed
    install_metadata_hooks
    install_pokemon_hooks
    install_battle_hooks
    install_storage_hooks
    install_gift_hooks
    install_test_input_hook
    install_menu_hooks
    install_learning_hooks
    install_first_run_hooks
    self.installed = true
    log("Hardcore Nuzlocke/Random setup installed successfully")
  rescue Exception => error
    log("INSTALL ERROR: #{error.class}: #{error.message}\n#{error.backtrace ? error.backtrace.join("\n") : ''}")
  end

  def self.install_metadata_hooks
    PokemonGlobalMetadata.class_eval do
      attr_accessor :pzn_hardcore_state
      if !method_defined?(:pzn_hardcore_original_nuzlocke_set)
        alias_method :pzn_hardcore_original_nuzlocke_set, :nuzlocke=
        def nuzlocke=(value)
          data = @pzn_hardcore_state
          if PZHardcoreNuzlocke.installed && data && data[:activated] && !data[:failed]
            @nuzlocke = true
            return true
          end
          if PZHardcoreNuzlocke.installed && value && (!data || !data[:activated])
            @pzn_hardcore_state = PZHardcoreNuzlocke.default_state if !data
            @pzn_hardcore_state[:pending_first_setup] = true
          end
          pzn_hardcore_original_nuzlocke_set(value)
        end
      end
    end
  end

  def self.install_pokemon_hooks
    PokeBattle_Pokemon.class_eval do
      attr_accessor :nuzlocke_dead
      attr_accessor :nuzlocke_death_area
      attr_accessor :nuzlocke_death_time
      attr_accessor :nuzlocke_origin_area

      if !method_defined?(:pzn_hardcore_original_hp_set)
        alias_method :pzn_hardcore_original_hp_set, :hp=
        def hp=(value)
          old_hp = @hp.to_i
          if PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(self) && value.to_i > 0
            return pzn_hardcore_original_hp_set(0)
          end
          result = pzn_hardcore_original_hp_set(value)
          PZHardcoreNuzlocke.record_death(self) if old_hp > 0 && @hp.to_i <= 0
          result
        end
      end

      if !method_defined?(:pzn_hardcore_original_heal_hp)
        alias_method :pzn_hardcore_original_heal_hp, :healHP
        def healHP
          return if PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(self)
          pzn_hardcore_original_heal_hp
        end
      end

      if !method_defined?(:pzn_hardcore_original_exp_set)
        alias_method :pzn_hardcore_original_exp_set, :exp=
        def exp=(value)
          if PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.rule?(:level_caps) && !(isEgg? rescue false)
            maximum = PZHardcoreNuzlocke.maximum_exp_for(self)
            value = maximum if maximum && value.to_i > maximum
          end
          pzn_hardcore_original_exp_set(value)
        end
      end
    end
  end

  def self.install_battle_hooks
    PokeBattle_BattleCommon.module_eval do
      if !method_defined?(:pzn_hardcore_original_throw_ball)
        alias_method :pzn_hardcore_original_throw_ball, :pbThrowPokeBall
        def pbThrowPokeBall(idxPokemon, ball, rareness=nil, showplayer=false)
          battler = nil
          if pbIsOpposing?(idxPokemon)
            battler = self.battlers[idxPokemon]
          else
            battler = self.battlers[idxPokemon].pbOppositeOpposing
          end
          battler = battler.pbPartner if battler && battler.isFainted?
          pokemon = battler ? battler.pokemon : nil
          allowed = PZHardcoreNuzlocke.capture_allowed?(self, pokemon)
          if pokemon && !allowed[0]
            PZHardcoreNuzlocke.restore_blocked_ball(self, ball)
            @scene.pbThrowAndDeflect(ball, 1)
            pbDisplay(allowed[1])
            return
          end
          previous_decision = @decision
          result = pzn_hardcore_original_throw_ball(idxPokemon, ball, rareness, showplayer)
          if pokemon && @decision == 4 && previous_decision != 4
            PZHardcoreNuzlocke.record_battle_capture(self, pokemon)
          end
          result
        end
      end
    end

    PokeBattle_Battle.class_eval do
      if !method_defined?(:pzn_hardcore_original_start_core)
        alias_method :pzn_hardcore_original_start_core, :pbStartBattleCore
        def pbStartBattleCore(canlose)
          if PZHardcoreNuzlocke.active?
            PZHardcoreNuzlocke.enforce_party_level_cap!
            @shiftStyle = false if PZHardcoreNuzlocke.rule?(:set_style)
          end
          PZHardcoreNuzlocke.begin_wild_battle(self)
          pzn_hardcore_original_start_core(canlose)
        end
      end

      if !method_defined?(:pzn_hardcore_original_register_item)
        alias_method :pzn_hardcore_original_register_item, :pbRegisterItem
        def pbRegisterItem(idxPokemon, idxItem, idxTarget=nil)
          player_owned = pbOwnedByPlayer?(idxPokemon) rescue (idxPokemon % 2 == 0)
          if player_owned && PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.rule?(:no_battle_items) && !pbIsPokeBall?(idxItem)
            $PokemonBag.pbStoreItem(idxItem) if $PokemonBag.pbCanStore?(idxItem)
            pbDisplay(_INTL("Las reglas Nuzlocke prohíben usar objetos en combate."))
            return false
          end
          pzn_hardcore_original_register_item(idxPokemon, idxItem, idxTarget)
        end
      end

      if !method_defined?(:pzn_hardcore_original_end_battle)
        alias_method :pzn_hardcore_original_end_battle, :pbEndOfBattle
        def pbEndOfBattle(canlose=false)
          result = pzn_hardcore_original_end_battle(canlose)
          PZHardcoreNuzlocke.finish_wild_battle(self)
          result
        end
      end
    end

    PokeBattle_SafariZone.class_eval do
      if !method_defined?(:pzn_hardcore_original_safari_start)
        alias_method :pzn_hardcore_original_safari_start, :pbStartBattle
        def pbStartBattle
          PZHardcoreNuzlocke.begin_wild_battle(self)
          result = pzn_hardcore_original_safari_start
          PZHardcoreNuzlocke.finish_wild_battle(self)
          result
        end
      end
    end

    PokeBattle_Scene.class_eval do
      if !method_defined?(:pzn_hardcore_original_scene_start)
        alias_method :pzn_hardcore_original_scene_start, :pbStartBattle
        def pbStartBattle(battle)
          result = pzn_hardcore_original_scene_start(battle)
          PZHardcoreNuzlocke.show_encounter_notice(battle)
          result
        end
      end
    end
  end

  def self.install_storage_hooks
    PokemonStorageScreen.class_eval do
      if !method_defined?(:pzn_hardcore_original_withdraw)
        alias_method :pzn_hardcore_original_withdraw, :pbWithdraw
        def pbWithdraw(selected, heldpoke)
          pokemon = heldpoke || @storage[selected[0], selected[1]]
          if PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(pokemon)
            pbDisplay(_INTL("Un Pokémon del Cementerio no puede volver al equipo."))
            return false
          end
          pzn_hardcore_original_withdraw(selected, heldpoke)
        end
      end

      if !method_defined?(:pzn_hardcore_original_place)
        alias_method :pzn_hardcore_original_place, :pbPlace
        def pbPlace(selected)
          if selected[0] == -1 && PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(@heldpkmn)
            pbDisplay(_INTL("Un Pokémon del Cementerio no puede volver al equipo."))
            return false
          end
          pzn_hardcore_original_place(selected)
        end
      end

      if !method_defined?(:pzn_hardcore_original_swap)
        alias_method :pzn_hardcore_original_swap, :pbSwap
        def pbSwap(selected)
          if selected[0] == -1 && PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(@heldpkmn)
            pbDisplay(_INTL("Un Pokémon del Cementerio no puede volver al equipo."))
            return false
          end
          pzn_hardcore_original_swap(selected)
        end
      end
    end

    PokemonStorage.class_eval do
      if !method_defined?(:pzn_hardcore_original_storage_move)
        alias_method :pzn_hardcore_original_storage_move, :pbMove
        def pbMove(boxDst, indexDst, boxSrc, indexSrc)
          pokemon = self[boxSrc, indexSrc]
          return false if boxDst == -1 && PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(pokemon)
          pzn_hardcore_original_storage_move(boxDst, indexDst, boxSrc, indexSrc)
        end
      end

      if !method_defined?(:pzn_hardcore_original_caught_to_party)
        alias_method :pzn_hardcore_original_caught_to_party, :pbMoveCaughtToParty
        def pbMoveCaughtToParty(pokemon)
          return false if PZHardcoreNuzlocke.active? && PZHardcoreNuzlocke.dead?(pokemon)
          pzn_hardcore_original_caught_to_party(pokemon)
        end
      end
    end
  end

  def self.install_gift_hooks
    Object.class_eval do
      if (method_defined?(:pbAddPokemon) || private_method_defined?(:pbAddPokemon)) && !private_method_defined?(:pzn_hardcore_original_add_pokemon)
        alias_method :pzn_hardcore_original_add_pokemon, :pbAddPokemon
        def pbAddPokemon(pokemon, level=nil, seeform=true)
          token = PZHardcoreNuzlocke.prepare_gift(pokemon)
          return false if !token
          result = pzn_hardcore_original_add_pokemon(pokemon, level, seeform)
          PZHardcoreNuzlocke.finish_gift(token, pokemon) if result
          result
        end
        private :pbAddPokemon
      end

      if (method_defined?(:pbAddPokemonSilent) || private_method_defined?(:pbAddPokemonSilent)) && !private_method_defined?(:pzn_hardcore_original_add_pokemon_silent)
        alias_method :pzn_hardcore_original_add_pokemon_silent, :pbAddPokemonSilent
        def pbAddPokemonSilent(pokemon, level=nil, seeform=true)
          token = PZHardcoreNuzlocke.prepare_gift(pokemon)
          return false if !token
          result = pzn_hardcore_original_add_pokemon_silent(pokemon, level, seeform)
          PZHardcoreNuzlocke.finish_gift(token, pokemon) if result
          result
        end
        private :pbAddPokemonSilent
      end

      if (method_defined?(:pbAddToParty) || private_method_defined?(:pbAddToParty)) && !private_method_defined?(:pzn_hardcore_original_add_to_party)
        alias_method :pzn_hardcore_original_add_to_party, :pbAddToParty
        def pbAddToParty(pokemon, level=nil, seeform=true)
          token = PZHardcoreNuzlocke.prepare_gift(pokemon)
          return false if !token
          result = pzn_hardcore_original_add_to_party(pokemon, level, seeform)
          PZHardcoreNuzlocke.finish_gift(token, pokemon) if result
          result
        end
        private :pbAddToParty
      end

      if (method_defined?(:pbAddToPartySilent) || private_method_defined?(:pbAddToPartySilent)) && !private_method_defined?(:pzn_hardcore_original_add_to_party_silent)
        alias_method :pzn_hardcore_original_add_to_party_silent, :pbAddToPartySilent
        def pbAddToPartySilent(pokemon, level=nil, seeform=true)
          token = PZHardcoreNuzlocke.prepare_gift(pokemon)
          return false if !token
          result = pzn_hardcore_original_add_to_party_silent(pokemon, level, seeform)
          PZHardcoreNuzlocke.finish_gift(token, pokemon) if result
          result
        end
        private :pbAddToPartySilent
      end

      if (method_defined?(:pbAddForeignPokemon) || private_method_defined?(:pbAddForeignPokemon)) && !private_method_defined?(:pzn_hardcore_original_add_foreign)
        alias_method :pzn_hardcore_original_add_foreign, :pbAddForeignPokemon
        def pbAddForeignPokemon(pokemon, level=nil, ownerName=nil, nickname=nil, ownerGender=0, seeform=true)
          token = PZHardcoreNuzlocke.prepare_gift(pokemon)
          return false if !token
          result = pzn_hardcore_original_add_foreign(pokemon, level, ownerName, nickname, ownerGender, seeform)
          PZHardcoreNuzlocke.finish_gift(token, pokemon) if result
          result
        end
        private :pbAddForeignPokemon
      end

      if (method_defined?(:pbGenerateEgg) || private_method_defined?(:pbGenerateEgg)) && !private_method_defined?(:pzn_hardcore_original_generate_egg)
        alias_method :pzn_hardcore_original_generate_egg, :pbGenerateEgg
        def pbGenerateEgg(pokemon, text="")
          token = PZHardcoreNuzlocke.prepare_gift(pokemon)
          return false if !token
          result = pzn_hardcore_original_generate_egg(pokemon, text)
          PZHardcoreNuzlocke.finish_gift(token, pokemon) if result
          result
        end
        private :pbGenerateEgg
      end
    end
  end

  def self.install_menu_hooks
    PokemonOptionScene.class_eval do
      if !method_defined?(:pzn_hardcore_original_add_on_options)
        alias_method :pzn_hardcore_original_add_on_options, :pbAddOnOptions
        def pbAddOnOptions(options)
          result = pzn_hardcore_original_add_on_options(options)
          return result if !defined?($PokemonGlobal) || !$PokemonGlobal
          challenge_present = result.any? { |option| option.is_a?(PZNuzlockeMenuOption) }
          learning_present = result.any? { |option| option.is_a?(PZLearningMenuOption) }
          chart_present = result.any? { |option| option.is_a?(PZTypeChartMenuOption) }
          result << PZNuzlockeMenuOption.new if !challenge_present
          result << PZLearningMenuOption.new if !learning_present
          result << PZTypeChartMenuOption.new if !chart_present
          result
        end
      end

      if !method_defined?(:pzn_hardcore_original_options_update_scene)
        alias_method :pzn_hardcore_original_options_update_scene, :pbUpdate
        def pbUpdate
          pzn_hardcore_original_options_update_scene
          window = @sprites["option"] rescue nil
          options = window.instance_variable_get(:@options) rescue nil
          selected = options && window.index < options.length ? options[window.index] : nil
          if selected.is_a?(PZNuzlockeMenuOption)
            @sprites["textbox"].text = "Configura y consulta Nuzlocke, Random, progreso, zonas y Cementerio."
          elsif selected.is_a?(PZLearningMenuOption)
            @sprites["textbox"].text = "Configura explicaciones, eficacia, multiplicadores y ayudas al cambiar Pokémon."
          elsif selected.is_a?(PZTypeChartMenuOption)
            @sprites["textbox"].text = "Consulta fortalezas, debilidades, resistencias e inmunidades de cada tipo."
          end
        end
      end
    end

    Window_PokemonOption.class_eval do
      if !method_defined?(:pzn_hardcore_original_option_update)
        alias_method :pzn_hardcore_original_option_update, :update
        def update
          pzn_hardcore_original_option_update
          selected = self.index < @options.length ? @options[self.index] : nil
          if self.active && selected.is_a?(PZNuzlockeMenuOption) && Input.trigger?(Input::C)
            PZHardcoreNuzlocke.safe_ui("Desafíos") { PZHardcoreNuzlocke.open_menu }
            Input.update
            refresh
          elsif self.active && selected.is_a?(PZLearningMenuOption) && Input.trigger?(Input::C)
            PZHardcoreNuzlocke.safe_ui("Ayudas de combate") { PZHardcoreNuzlocke.open_learning_setup }
            Input.update
            refresh
          elsif self.active && selected.is_a?(PZTypeChartMenuOption) && Input.trigger?(Input::C)
            PZHardcoreNuzlocke.safe_ui("Tabla de tipos") { PZHardcoreNuzlocke.open_type_chart }
            Input.update
            refresh
          end
        end
      end
    end

    DP_PauseMenu.class_eval do
      if !method_defined?(:pzn_hardcore_original_pause_main)
        alias_method :pzn_hardcore_original_pause_main, :main
        def main
          PZHardcoreNuzlocke.add_pause_menu_option(self)
          PZHardcoreNuzlocke.draw_pause_info(@sprites, @globalVp)
          pzn_hardcore_original_pause_main
        end
      end

      if !method_defined?(:pzn_hardcore_original_pause_update)
        alias_method :pzn_hardcore_original_pause_update, :update
        def update
          pzn_hardcore_original_pause_update
          if Input.trigger?(Input::R)
            @sprites.visible = false
            PZHardcoreNuzlocke.safe_ui("Desafíos desde pausa") { PZHardcoreNuzlocke.open_menu }
            @sprites.visible = true
            PZHardcoreNuzlocke.draw_pause_info(@sprites, @globalVp)
            Input.update
          end
        end
      end
    end
  end

  def self.install_learning_hooks
    FightMenuButtons.class_eval do
      attr_accessor :pzn_learning_battler
      if !method_defined?(:pzn_learning_original_refresh)
        alias_method :pzn_learning_original_refresh, :refresh
        def refresh(index, moves, megaButton)
          pzn_learning_original_refresh(index, moves, megaButton)
          PZHardcoreNuzlocke.enhance_fight_buttons(self.bitmap, moves, @pzn_learning_battler)
        end
      end
    end

    FightMenuDisplay.class_eval do
      if !method_defined?(:pzn_learning_original_update)
        alias_method :pzn_learning_original_update, :update
        def update
          @buttons.pzn_learning_battler = @battler if @buttons && @buttons.respond_to?(:pzn_learning_battler=)
          pzn_learning_original_update
        end
      end
    end

    PokemonScreen_Scene.class_eval do
      if !method_defined?(:pzn_learning_original_update)
        alias_method :pzn_learning_original_update, :update
        def update
          pzn_learning_original_update
          PZHardcoreNuzlocke.refresh_switch_help(self)
        end
      end
    end

    PokeBattle_Scene.class_eval do
      if !method_defined?(:pzn_learning_original_switch)
        alias_method :pzn_learning_original_switch, :pbSwitch
        def pbSwitch(index, lax, cancancel)
          PZHardcoreNuzlocke.learning_switch_context = {
            :battle=>@battle,
            :battler_index=>index
          }
          pzn_learning_original_switch(index, lax, cancancel)
        ensure
          PZHardcoreNuzlocke.learning_switch_context = nil
        end
      end

      if !method_defined?(:pzn_learning_original_fight_menu)
        alias_method :pzn_learning_original_fight_menu, :pbFightMenu
        def pbFightMenu(index)
          fightbox = PokeBattle_Scene.const_get(:FIGHTBOX)
          pbShowWindow(fightbox)
          cw = @sprites["fightwindow"]
          battler = @battle.battlers[index]
          cw.battler = battler
          lastIndex = @lastmove[index]
          if battler.moves[lastIndex].id != 0
            cw.setIndex(lastIndex)
          else
            cw.setIndex(0)
          end
          cw.megaButton = 0
          cw.megaButton = 1 if @battle.pbCanMegaEvolve?(index)
          pbSelectBattler(index)
          pbRefresh
          loop do
            pbGraphicsUpdate
            pbInputUpdate
            pbFrameUpdate(cw)
            if Input.trigger?(Input::LEFT) && (cw.index & 1) == 1
              pbPlayCursorSE() if cw.setIndex(cw.index - 1)
            elsif Input.trigger?(Input::RIGHT) && (cw.index & 1) == 0
              pbPlayCursorSE() if cw.setIndex(cw.index + 1)
            elsif Input.trigger?(Input::UP) && (cw.index & 2) == 2
              pbPlayCursorSE() if cw.setIndex(cw.index - 2)
            elsif Input.trigger?(Input::DOWN) && (cw.index & 2) == 0
              pbPlayCursorSE() if cw.setIndex(cw.index + 2)
            end

            if Input.trigger?(Input::X) && PZHardcoreNuzlocke.learning_setting?(:move_info)
              move = battler.moves[cw.index]
              if move && move.id != 0
                PZHardcoreNuzlocke.safe_ui("Información de ataque") do
                  PZHardcoreNuzlocke.open_move_info(move, battler)
                end
                pbShowWindow(fightbox)
                pbRefresh
              end
              next
            end

            if Input.trigger?(Input::C)
              move = battler.moves[cw.index]
              target = PZHardcoreNuzlocke.primary_opponent(battler)
              modifier = PZHardcoreNuzlocke.move_modifier(move, battler, target)
              damaging = move && move.respond_to?(:basedamage) && move.basedamage.to_i > 0
              if damaging && modifier == 0 && PZHardcoreNuzlocke.learning_setting?(:warn_no_effect)
                target_name = target ? target.name : "el rival"
                explanation = "#{move.name} no causa daño a #{target_name} por la inmunidad de tipos."
                proceed = PZHardcoreNuzlocke.confirm_choice(
                  "¿Deseas usarlo de todas formas?", explanation, "Ataque sin efecto")
                pbShowWindow(fightbox)
                pbRefresh
                next if !proceed
              end
              ret = cw.index
              pbPlayDecisionSE()
              @lastmove[index] = ret
              return ret
            elsif Input.trigger?(Input::A)
              if @battle.pbCanMegaEvolve?(index)
                @battle.pbRegisterMegaEvolution(index)
                cw.megaButton = 2
                pbPlayDecisionSE()
              end
            elsif Input.trigger?(Input::B)
              @lastmove[index] = cw.index
              pbPlayCancelSE()
              return -1
            end
          end
        end
      end
    end
  end

  def self.install_first_run_hooks
    Scene_Map.class_eval do
      if !method_defined?(:pzn_hardcore_original_transfer_player)
        alias_method :pzn_hardcore_original_transfer_player, :transfer_player
        def transfer_player(cancelVehicles=true)
          leaving_intro = defined?($game_map) && $game_map && $game_map.map_id == 1 &&
            defined?($game_temp) && $game_temp && $game_temp.player_new_map_id != 1
          result = pzn_hardcore_original_transfer_player(cancelVehicles)
          @pzn_first_run_setup_pending = true if leaving_intro
          result
        end
      end

      if !method_defined?(:pzn_hardcore_original_first_run_update)
        alias_method :pzn_hardcore_original_first_run_update, :update
        def update
          result = pzn_hardcore_original_first_run_update
          challenge_state = PZHardcoreNuzlocke.state rescue nil
          ready = @pzn_first_run_setup_pending && !@pzn_first_run_setup_running &&
            challenge_state && !challenge_state[:first_run_setup_done] &&
            defined?($game_map) && $game_map && $game_map.map_id != 1 &&
            defined?($game_temp) && $game_temp && !$game_temp.transition_processing
          if ready
            @pzn_first_run_setup_pending = false
            @pzn_first_run_setup_running = true
            begin
              PZHardcoreNuzlocke.safe_ui("Configuración inicial") { PZHardcoreNuzlocke.open_post_nuzlocke_first_run_setup }
            ensure
              @pzn_first_run_setup_running = false
            end
          end
          result
        end
      end
    end
  end
end
