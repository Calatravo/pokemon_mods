# encoding: UTF-8

PZ_HARDCORE_NUZLOCKE_ROOT = File.dirname(__FILE__) unless defined?(PZ_HARDCORE_NUZLOCKE_ROOT)

[
  "Config/rules.rb",
  "Config/areas.rb",
  "Scripts/core.rb",
  "Scripts/encounters.rb",
  "Scripts/death.rb",
  "Scripts/random.rb",
  "Scripts/ui.rb",
  "Scripts/type_chart.rb",
  "Scripts/learning.rb",
  "Scripts/ui_smoke.rb",
  "Scripts/hooks.rb"
].each do |relative_path|
  load File.join(PZ_HARDCORE_NUZLOCKE_ROOT, relative_path)
end

PZHardcoreNuzlocke.schedule_install!
scripts_info = defined?($RGSS_SCRIPTS) && $RGSS_SCRIPTS ? $RGSS_SCRIPTS.length.to_s : "unavailable"
last_script = if defined?($RGSS_SCRIPTS) && $RGSS_SCRIPTS && $RGSS_SCRIPTS[-1]
  data = $RGSS_SCRIPTS[-1][2]
  "#{ $RGSS_SCRIPTS[-1][1] }/#{data ? data[0, 4].unpack('H*')[0] : 'nil'}"
else
  "none"
end
PZHardcoreNuzlocke.log("Loader initialized; RGSS script table: #{scripts_info}; last=#{last_script}")
