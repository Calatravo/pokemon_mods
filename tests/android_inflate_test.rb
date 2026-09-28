# encoding: UTF-8
# Exercise the real preload inside isolated namespaces, without replacing the
# test process's own Ruby constants or Zlib implementation. Ruby 1.8 compatible.
path = File.expand_path('../installer/preload-snippet.rb', File.dirname(__FILE__))
snippet = File.open(path, 'rb') { |f| f.read }
[
  ['x86_64-linux-android', '1.8.1', true, 'native:x'],
  ['x86_64-linux-android', '3.1.0', true, 'original:x'],
  ['i386-mingw32', '1.8.7', true, 'original:x'],
  ['x86_64-linux-android', '1.8.1', false, 'original:x']
].each do |platform, version, native_available, expected|
  context = Module.new
  context.const_set(:RUBY_PLATFORM, platform)
  context.const_set(:RUBY_VERSION, version)
  context.module_eval <<-RUBY
    module Zlib
      class Inflate
        def self.inflate(string); 'original:' + string; end
      end
    end
    module MKXP; end
    def self.load(path); @loaded_path = path; end
  RUBY
  if native_available
    context.module_eval "def MKXP.zinflate(string); 'native:' + string; end"
  end
  2.times { context.module_eval(snippet, 'preload.rb') }
  inflate = context.const_get(:Zlib).const_get(:Inflate)
  raise "Wrong decompressor for #{platform}/#{version}" unless inflate.inflate('x') == expected
  raise 'Mod loader not reached' unless context.instance_variable_get(:@loaded_path)
end
puts 'PASS Android Ruby 1.8 native inflate, repeated preload, Windows/modern Ruby/missing API unchanged'
