# encoding: UTF-8

# Default used by a manual installation. install.ps1 replaces this file in the
# target game with the detected language and compatibility profile.
module PZHardcoreNuzlocke
  module InstallConfig
    LANGUAGE = :es unless const_defined?(:LANGUAGE)
    PROFILE = :es_218 unless const_defined?(:PROFILE)
  end
end
