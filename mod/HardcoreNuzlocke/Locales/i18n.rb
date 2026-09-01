# encoding: UTF-8

module PZHardcoreNuzlocke
  module I18n
    LANGUAGES = [:es, :en, :fr]
    LANGUAGE_NAMES = ["Español", "English", "Français"]
    @strings = {}

    def self.register(language, strings)
      @strings[language] = strings
    end

    def self.supported?(language)
      LANGUAGES.include?(language)
    end

    def self.lookup(language, key)
      table = @strings[language] || @strings[:es] || {}
      fallback = @strings[:es] || {}
      table.has_key?(key) ? table[key] : (fallback.has_key?(key) ? fallback[key] : key.to_s)
    end
  end

  def self.language
    value = nil
    if defined?($PokemonSystem) && $PokemonSystem
      value = $PokemonSystem.instance_variable_get(:@pzn_mod_language)
    end
    if !I18n.supported?(value)
      value = if defined?(InstallConfig::LANGUAGE)
        InstallConfig::LANGUAGE
      else
        :es
      end
    end
    I18n.supported?(value) ? value : :es
  rescue Exception
    :es
  end

  def self.set_language(value)
    value = value.to_sym rescue value
    return false if !I18n.supported?(value)
    $PokemonSystem.instance_variable_set(:@pzn_mod_language, value) if defined?($PokemonSystem) && $PokemonSystem
    @area_index = nil
    log("Language changed to #{value}") if respond_to?(:log)
    true
  end

  def self.language_index
    I18n::LANGUAGES.index(language) || 0
  end

  def self.t(key, *arguments)
    text = I18n.lookup(language, key).to_s
    return text if arguments.length == 0
    text % arguments
  rescue Exception
    I18n.lookup(:es, key).to_s
  end
end
