# encoding: UTF-8

module PZHardcoreNuzlocke
  module Config
    SUPPORTED_PROFILES = {
      :es_218=>{:language=>:es, :version=>"2.18"},
      :en_213=>{:language=>:en, :version=>"2.13"},
      :fr_212p1=>{:language=>:fr, :version=>"2.12 + Patch 1"}
    }

    def self.profile
      value = if defined?(PZHardcoreNuzlocke::InstallConfig::PROFILE)
        PZHardcoreNuzlocke::InstallConfig::PROFILE
      else
        :es_218
      end
      SUPPORTED_PROFILES.has_key?(value) ? value : :es_218
    rescue Exception
      :es_218
    end

    def self.profile_data
      SUPPORTED_PROFILES[profile]
    end

    def self.profile_valid?
      return false if !profile_data
      return true if !defined?($data_mapinfos) || !$data_mapinfos
      missing = []
      AREAS.each_value do |data|
        data[1].each { |map_id| missing << map_id if !$data_mapinfos[map_id] }
      end
      missing.length == 0
    rescue Exception
      false
    end
  end
end
