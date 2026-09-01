# BEGIN POKEMON_MODS HARDCORE_NUZLOCKE
# Loads the mod before Scripts.rxdata. The mod waits until Pokemon Z has
# defined its classes and then installs the hooks in memory.
begin
  load File.join(File.dirname(__FILE__), "Mods", "HardcoreNuzlocke", "loader.rb")
rescue Exception => error
  begin
    log_path = File.join(File.dirname(__FILE__), "Mods", "HardcoreNuzlocke", "nuzlocke.log")
    File.open(log_path, "ab") do |file|
      file.write("[PRELOAD ERROR] #{error.class}: #{error.message}\n")
      file.write(error.backtrace.join("\n")) if error.backtrace
      file.write("\n")
    end
  rescue Exception
  end
end
# END POKEMON_MODS HARDCORE_NUZLOCKE
