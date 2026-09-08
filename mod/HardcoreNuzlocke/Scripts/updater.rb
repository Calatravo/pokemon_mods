# encoding: UTF-8

module PZHardcoreNuzlocke
  def self.launch_update_worker(mode, version=nil)
    root = File.expand_path(PZ_HARDCORE_NUZLOCKE_ROOT)
    game = File.expand_path('../..', root)
    helper = File.join(root, 'Updater', 'update.ps1')
    powershell = File.join(ENV['SystemRoot'] || 'C:/Windows', 'System32/WindowsPowerShell/v1.0/powershell.exe')
    args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', helper,
            '-Mode', mode, '-GamePath', game, '-Session', @update_session, '-GamePid', Process.pid.to_s]
    args += ['-Version', version] if version
    args += ['-Language', language.to_s]
    # ShellExecute receives arguments directly, without cmd.exe or interpolated PS code.
    parameters = args.collect { |arg| '"' + arg.to_s + '"' }.join(' ')
    # The shipped game uses Ruby 1.8, which has no String#encode.
    @update_wide ||= Win32API.new('kernel32', 'MultiByteToWideChar', 'ilpipi', 'i')
    wide = proc do |value|
      size = @update_wide.call(65001, 0, value, -1, nil, 0)
      buffer = "\0" * (size * 2)
      @update_wide.call(65001, 0, value, -1, buffer, size)
      buffer
    end
    @update_shell ||= Win32API.new('shell32', 'ShellExecuteW', 'lppppl', 'l')
    result = @update_shell.call(0, wide.call('open'), wide.call(powershell), wide.call(parameters), wide.call(game), 0)
    raise 'Could not start Windows updater' if result <= 32
  end

  def self.start_update_check
    return if @update_started
    @update_started = true
    return unless RUBY_PLATFORM =~ /mswin|mingw/i
    return unless defined?(Win32API)
    @update_session = "#{Process.pid}-#{Time.now.to_i}"
    @update_status_path = File.expand_path("../.pzn-updates/#{@update_session}/status.txt", PZ_HARDCORE_NUZLOCKE_ROOT)
    launch_update_worker('Check')
  rescue Exception => error
    log("Update check unavailable: #{error.message}")
  end

  def self.poll_update_notice
    return if @update_ui_busy || !@update_status_path || @update_finished
    return if @update_poll_at && Time.now < @update_poll_at
    @update_poll_at = Time.now + 1
    return unless @update_title_active
    if @update_accepted && Time.now > @update_accepted + 15
      @update_finished = true
      show_info(t(:update_failed), t(:update_title))
      return
    end
    return unless File.file?(@update_status_path)
    status = File.read(@update_status_path).strip
    @update_ui_busy = true
    if status =~ /\Aavailable:(\d+\.\d+\.\d+)\z/ && !@update_asked
      version = $1
      @update_asked = true
      if confirm_choice(t(:update_question, version), t(:update_explanation), t(:update_title))
        launch_update_worker('Install', version)
        @update_accepted = Time.now
      else
        @update_finished = true
      end
    elsif status == 'closing' && @update_accepted
      close_for_update
    elsif status == 'failed' || status == 'current'
      @update_finished = true
      show_info(t(:update_failed), t(:update_title)) if @update_accepted
    end
    @update_ui_busy = false
  rescue Exception => error
    @update_finished = true
    log("Update notice error: #{error.message}")
    @update_ui_busy = false
  end

  def self.close_for_update
    exit!
  end

  def self.install_update_title_hook
    PokemonLoadScene.class_eval do
      unless method_defined?(:pzn_update_original_choose)
        alias_method :pzn_update_original_choose, :pbChoose
        def pbChoose(*args)
          PZHardcoreNuzlocke.instance_variable_set(:@update_title_active, true)
          begin
            pzn_update_original_choose(*args)
          ensure
            PZHardcoreNuzlocke.instance_variable_set(:@update_title_active, false)
          end
        end
        alias_method :pzn_update_original_load_update, :pbUpdate
        def pbUpdate
          result = pzn_update_original_load_update
          PZHardcoreNuzlocke.poll_update_notice
          # Only after consent: allow the local worker to acknowledge ownership
          # before exiting. Network requests happen in that worker after exit.
          while PZHardcoreNuzlocke.instance_variable_get(:@update_accepted) &&
                !PZHardcoreNuzlocke.instance_variable_get(:@update_finished)
            Graphics.update
            Input.update
            PZHardcoreNuzlocke.poll_update_notice
          end
          result
        end
      end
    end
  end
end
