# encoding: UTF-8
# Run in a fresh Ruby process; also compatible with the game's Ruby 1.8 runtime.
load File.expand_path('../mod/HardcoreNuzlocke/Scripts/hooks.rb', File.dirname(__FILE__))

module Graphics
  class << self
    def update; @test_updates = (@test_updates || 0) + 1; end
    def test_updates; @test_updates || 0; end
  end
end

module PZHardcoreNuzlocke
  class << self
    attr_accessor :installed, :test_ready
    attr_reader :test_installs, :test_validations, :test_ticks
    def log(message); end
    def final_install_ready?; !!test_ready; end
    def install!
      @test_installs = (@test_installs || 0) + 1
      self.installed = true
    end
    def validate_installation!; @test_validations = (@test_validations || 0) + 1; end
    def tick; @test_ticks = (@test_ticks || 0) + 1; end
  end
end

def assert_bootstrap(value, message)
  raise message unless value
end

# An existing Windows bridge remains responsible for installation.
$RGSS_SCRIPTS = [[0, 'PZ Hardcore Nuzlocke Bridge', '']]
PZHardcoreNuzlocke.schedule_install!
assert_bootstrap(!Graphics.respond_to?(:pzn_hardcore_runtime_update), 'duplicate persistent bridge')
PZHardcoreNuzlocke.instance_variable_set(:@bridge_scheduled, false)

# JoiPlay has no script table during preload. Installation must still be
# deferred until the game is ready, then run and validate exactly once.
$RGSS_SCRIPTS = nil
PZHardcoreNuzlocke.schedule_install!
PZHardcoreNuzlocke.schedule_install!
Graphics.update
assert_bootstrap(!PZHardcoreNuzlocke.installed, 'installed before game classes were ready')
PZHardcoreNuzlocke.test_ready = true
Graphics.update
Graphics.update
assert_bootstrap(PZHardcoreNuzlocke.test_installs == 1, 'installation did not run exactly once')
assert_bootstrap(PZHardcoreNuzlocke.test_validations == 1, 'validation did not run exactly once')
assert_bootstrap(PZHardcoreNuzlocke.test_ticks == 2, 'runtime updates were not preserved')
assert_bootstrap(Graphics.test_updates == 3, 'original graphics updates were not preserved')
puts 'PASS bootstrap with absent script table, readiness, idempotency and persistent bridge'
