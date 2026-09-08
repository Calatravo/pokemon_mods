# encoding: UTF-8
load File.expand_path('../mod/HardcoreNuzlocke/Scripts/updater.rb', File.dirname(__FILE__))
module PZHardcoreNuzlocke
  def self.t(key, *args); key.to_s; end
  def self.log(message); end
  def self.launch_update_worker(*args); (@launches ||= []) << args; end
  def self.confirm_choice(*args)
    @questions += 1
    poll_update_notice # Graphics.update may re-enter the UI; must not clear the guard.
    raise 'Reentrant guard cleared' unless @update_ui_busy
    @answer
  end
  def self.show_info(*args); @notices << args[0]; end
  def self.setup_test(path, answer)
    @update_status_path = path
    @update_finished = @update_ui_busy = @update_asked = @update_accepted = @update_poll_at = nil
    @update_title_active = true
    @closed = false
    @questions = 0; @launches = []; @notices = []; @answer = answer
  end
  def self.poll_test; @update_poll_at = nil; poll_update_notice; end
  def self.close_for_update; @closed = true; @update_finished = true; end
  def self.closed?; @closed; end
  def self.result; [@questions, @launches, @notices]; end
end
def assert_update(condition)
  raise 'Updater UI assertion failed' unless condition
end
$game_temp = Struct.new(:in_battle, :message_window_showing, :transition_processing).new(false, false, false)
$game_map = Struct.new(:map_id).new(2)
$game_system = nil
path = File.join(ENV['TEMP'] || '.', "pzn-ui-#{Process.pid}.txt")
begin
  File.open(path, 'w') { |f| f.write('available:1.2.0') }
  PZHardcoreNuzlocke.setup_test(path, false)
  PZHardcoreNuzlocke.instance_variable_set(:@update_title_active, false)
  PZHardcoreNuzlocke.poll_test
  assert_update(PZHardcoreNuzlocke.result[0] == 0)
  PZHardcoreNuzlocke.instance_variable_set(:@update_title_active, true)
  2.times { PZHardcoreNuzlocke.poll_test }
  assert_update(PZHardcoreNuzlocke.result[0] == 1 && PZHardcoreNuzlocke.result[1].empty?)
  PZHardcoreNuzlocke.setup_test(path, true)
  2.times { PZHardcoreNuzlocke.poll_test }
  assert_update(PZHardcoreNuzlocke.result[1] == [['Install', '1.2.0']])
  File.open(path, 'w') { |f| f.write('closing') }
  2.times { PZHardcoreNuzlocke.poll_test }
  assert_update(PZHardcoreNuzlocke.closed?)
  PZHardcoreNuzlocke.setup_test(path, true)
  File.open(path, 'w') { |f| f.write('failed') }
  PZHardcoreNuzlocke.poll_test
  assert_update(PZHardcoreNuzlocke.result[2].empty?)
  class PokemonLoadScene
    def pbChoose(*args); pbUpdate; :continue; end
    def pbUpdate; :frame; end
  end
  2.times { PZHardcoreNuzlocke.install_update_title_hook }
  File.open(path, 'w') { |f| f.write('available:1.2.0') }
  PZHardcoreNuzlocke.setup_test(path, false)
  PZHardcoreNuzlocke.instance_variable_set(:@update_title_active, false)
  assert_update(PokemonLoadScene.new.pbChoose([]) == :continue)
  assert_update(PZHardcoreNuzlocke.result[0] == 1)
  assert_update(!PZHardcoreNuzlocke.instance_variable_get(:@update_title_active))
  puts 'PASS updater consent, decline, title-only notification and automatic close, offline silence and reentrancy'
ensure
  File.delete(path) if File.exist?(path)
end
