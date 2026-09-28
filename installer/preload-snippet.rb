# BEGIN POKEMON_MODS HARDCORE_NUZLOCKE
# Loads the mod before Scripts.rxdata. The mod waits until Pokemon Z has
# defined its classes and then installs the hooks in memory.
begin
  # Use JoiPlay's native decompressor for Ruby 1.8 constant scripts, which can
  # otherwise fail at evaluation. Other platforms and Rubies stay as-is.
  if RUBY_PLATFORM.to_s.include?("android") && RUBY_VERSION.to_s.index("1.8.") == 0 &&
      defined?(MKXP) && MKXP.respond_to?(:zinflate)
    class << Zlib::Inflate
      unless method_defined?(:pzn_original_inflate)
        alias_method :pzn_original_inflate, :inflate
        def inflate(string)
          MKXP.zinflate(string)
        end
      end
    end
  end
  load File.expand_path(File.join(File.dirname(__FILE__), "Mods", "HardcoreNuzlocke", "loader.rb"))
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
