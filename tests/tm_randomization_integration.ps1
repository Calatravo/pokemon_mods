# Uses the game's Ruby and item data without starting Main or writing saves.
[CmdletBinding()]
param(
    [string]$GameFolder = "$PSScriptRoot/../Pokemon Z V2.19",
    [switch]$Unpatched
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath "$PSScriptRoot/..").Path
$game = (Resolve-Path -LiteralPath $GameFolder).Path
$fixture = Join-Path $env:TEMP ('pzn-tm-integration-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
Copy-Item -LiteralPath "$game/Game.exe", "$game/Game.ini" -Destination $fixture
Get-ChildItem -LiteralPath $game -Filter '*.dll' | Copy-Item -Destination $fixture
$config = @{rgssVersion=1; gameFolder=$game; customScript="$fixture/test.rb"}
[IO.File]::WriteAllText("$fixture/mkxp.json", ($config | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
$ruby = @'
log = File.open('__FIXTURE__/result.txt', 'wb')
log.sync = true
$stdout = log
begin
  log.puts "Ruby #{RUBY_VERSION}"
  Dir.chdir('__GAME__')
  scripts = load_data('Data/Scripts.rxdata')
  scripts.each do |entry|
    name = entry[1].to_s
    next if name == 'Main' || name == 'PZ Hardcore Nuzlocke Bridge'
    source = defined?(MKXP) && MKXP.respond_to?(:zinflate) ? MKXP.zinflate(entry[2]) : Zlib::Inflate.inflate(entry[2])
    eval(source, TOPLEVEL_BINDING, name)
  end
  messages = Messages.new
  messages.instance_variable_set(:@messages, load_data('Data/messages.dat'))
  MessageTypes.send(:class_variable_set, :@@messages, messages)
  $ItemData = readItemList('Data/items.dat')
  module PZHardcoreNuzlocke
    def self.log(message); end
    def self.random_state; @test_config ||= {:enabled=>true, :event_items=>true}; end
    def self.current_item_event; @test_event; end
    def self.test_event=(value); @test_event = value; end
  end
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/core.rb'
  load '__REPO__/mod/HardcoreNuzlocke/Config/rules.rb'
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/random.rb'
  load '__REPO__/mod/HardcoreNuzlocke/Scripts/hooks.rb'
  class << PZHardcoreNuzlocke
    alias_method :pzn_tm_test_real_random_state, :random_state
  end
  module PZHardcoreNuzlocke
    def self.log(message); end
    def self.random_state; @test_config ||= {:enabled=>true, :event_items=>true}; end
    def self.current_item_event; @test_event; end
  end
  if '__UNPATCHED__' == '1'
    class << RandomizedChallenge
      alias_method :pzn_test_original_random_tm, :random_tm
    end
  end
  2.times { PZHardcoreNuzlocke.install_item_randomization_hooks }
  if '__UNPATCHED__' == '1'
    class << RandomizedChallenge
      alias_method :random_tm, :pzn_test_original_random_tm
    end
  end
  # Keep the real bag and delivery routines; suppress only message windows.
  class << Kernel
    def pbMessage(*arguments); end
  end
  $game_temp = Game_Temp.new
  $game_switches = Game_Switches.new
  $game_variables = Game_Variables.new
  $PokemonGlobal = PokemonGlobalMetadata.new
  $PokemonBag = PokemonBag.new
  $Trainer = PokeBattle_Trainer.new('TM test',0)
  $game_switches[409] = true
  $PokemonGlobal.random_items_enabled = true
  $PokemonGlobal.semi_random = false
  $PokemonGlobal.progressive_random = true
  all_tms = (1..PBItems.maxValue).find_all { |item| pbIsTechnicalMachine?(item) && !PBItems.getName(item).to_s.empty? }
  raise 'Incomplete game fixture' unless all_tms.length >= 100
  log.puts "Real TM pool: #{all_tms.length}"
  missing = all_tms[-1]
  all_tms[0...-1].each { |item| $PokemonBag.pbStoreItem(item) }
  $PokemonGlobal.tm_list = all_tms
  # Force the old retry loop to keep selecting an owned TM. The corrected
  # sampler has a single eligible item and must deliver it immediately.
  class << RandomizedChallenge
    def rand(limit); 0; end
  end
  result = RandomizedChallenge.random_tm
  raise "Missing TM replaced by ordinary item #{result}" unless result == missing
  class << RandomizedChallenge
    remove_method :rand
  end
  log.puts 'PASS last missing TM survives repeated owned-item rolls'
  # Reproduce an old cached list whose entries are owned, with most TMs absent.
  $PokemonBag = PokemonBag.new
  all_tms[0,12].each { |item| $PokemonBag.pbStoreItem(item) }
  $PokemonGlobal.tm_list = all_tms[0,12]
  $PokemonGlobal = Marshal.load(Marshal.dump($PokemonGlobal))
  20.times do
    result = RandomizedChallenge.determine_random_item(PBItems::TM01)
    raise 'Stale saved pool produces non-TM or owned TM' unless pbIsTechnicalMachine?(result) && !$PokemonBag.pbHasItem?(result)
  end
  raise 'Stale saved pool not repaired' unless $PokemonGlobal.tm_list == all_tms
  log.puts 'PASS incomplete saved pool with only 12 owned TMs'
  # Exercise the same calls used by yellow balls, NPCs and regent rewards.
  # Keep one slot missing so each path has an unambiguous expected delivery.
  [0,4,8].each do |badge_count|
    $Trainer.badges = Array.new(8) { |index| index < badge_count }
    [:pbItemBall, :pbReceiveItem].each do |path|
      $PokemonBag = PokemonBag.new
      all_tms[0...-1].each { |item| $PokemonBag.pbStoreItem(item) }
      PZHardcoreNuzlocke.test_event = Struct.new(:character_name).new(path == :pbItemBall ? 'objetoMT' : 'regente')
      raise "Delivery failed: #{path}" unless Kernel.send(path, :TM01)
      raise "#{path} lost the last missing TM at #{badge_count} badges" unless $PokemonBag.pbHasItem?(missing)
      move = $PokemonGlobal.tm_moves[missing]
      raise 'TM move was not saved' unless move && $ItemData[missing][ITEMMACHINE] == move
      raise 'Early TM exceeds progressive power cap' if badge_count < 3 && PBMoveData.new(move).basedamage > 70
    end
  end
  log.puts 'PASS pickup/NPC/regent delivery at 0/4/8 badges, progressive cap and saved TM moves'
  # Real renewable stones still yield their normal crafting material.
  $PokemonBag = PokemonBag.new
  PZHardcoreNuzlocke.test_event = Struct.new(:character_name).new('guijarros')
  raise 'Rock delivery failed' unless Kernel.pbItemBall(PBItems::GUIJARRO)
  raise 'Renewable rock was randomized' unless $PokemonBag.pbHasItem?(PBItems::GUIJARRO)
  log.puts 'PASS renewable rock resources preserved'
  # Exhaustion retains the existing ordinary-item fallback and terminates.
  $PokemonBag = PokemonBag.new
  all_tms.each { |item| $PokemonBag.pbStoreItem(item) }
  result = RandomizedChallenge.random_tm
  raise 'Exhausted pool did not use ordinary-item fallback' if pbIsTechnicalMachine?(result)
  log.puts 'PASS genuinely exhausted pool fallback'
  load '__REPO__/tests/tm_recovery_test.rb'
  log.puts 'RESULT PASS'
rescue Exception => error
  log.puts "RESULT FAIL: #{error.class}: #{error.message}"
  log.puts error.backtrace
ensure
  log.close
  exit!
end
'@
$ruby = $ruby.Replace('__FIXTURE__', $fixture.Replace('\','/')).Replace('__GAME__', $game.Replace('\','/')).Replace('__REPO__', $repo.Replace('\','/')).Replace('__UNPATCHED__', $(if ($Unpatched) {'1'} else {'0'}))
# Ruby 1.8 on Windows resolves filenames using the system ANSI code page.
[IO.File]::WriteAllText("$fixture/test.rb", $ruby, [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage))
$process = Start-Process -FilePath "$fixture/Game.exe" -WorkingDirectory $fixture -WindowStyle Hidden -PassThru
if (-not $process.WaitForExit(30000)) {
    Stop-Process -Id $process.Id -Force
    throw "TM integration timed out; inspect $fixture"
}
$result = [IO.File]::ReadAllText("$fixture/result.txt")
Write-Output $result
if (-not $result.Contains('RESULT PASS')) { throw "TM integration failed; inspect $fixture" }
$resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
$resolvedTemp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
if (-not $resolvedFixture.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -or
    (Split-Path -Leaf $resolvedFixture) -notlike 'pzn-tm-integration-*') {
    throw "Unsafe test cleanup path: $resolvedFixture"
}
Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
