# encoding: UTF-8
# Run in a fresh Ruby process. Compatible with Ruby 1.8.
source = File.expand_path('../installer/preload-snippet.rb', File.dirname(__FILE__))
root = File.join(ENV['TEMP'] || '/tmp', "pz-preload-test-#{$$}-#{Time.now.to_i}")
created = false
old_load_path = $LOAD_PATH.dup
begin
  Dir.mkdir(root)
  created = true
  Dir.mkdir(File.join(root, 'Mods'))
  Dir.mkdir(File.join(root, 'Mods', 'HardcoreNuzlocke'))
  loader = File.join(root, 'Mods', 'HardcoreNuzlocke', 'loader.rb')
  File.open(loader, 'wb') { |f| f.write('$pzn_test_loaded_from = __FILE__') }
  File.open(File.join(root, 'preload.rb'), 'wb') { |f| f.write(File.open(source, 'rb') { |input| input.read }) }
  $LOAD_PATH.replace([])
  Dir.chdir(root) do
    # JoiPlay evaluates a preload with a relative __FILE__ and empty load path.
    eval(File.open('preload.rb', 'rb') { |f| f.read }, TOPLEVEL_BINDING, 'preload.rb')
  end
  raise 'Preload did not load the mod using an absolute path' unless $pzn_test_loaded_from == File.expand_path(loader)
  puts 'PASS preload with relative __FILE__, empty load path and absolute mod load'
ensure
  $LOAD_PATH.replace(old_load_path)
  if created
    ['preload.rb', 'Mods/HardcoreNuzlocke/loader.rb', 'Mods/HardcoreNuzlocke/nuzlocke.log'].each do |relative|
      path = File.join(root, relative)
      File.delete(path) if File.file?(path)
    end
    ['Mods/HardcoreNuzlocke', 'Mods', ''].each { |relative| Dir.rmdir(File.join(root, relative)) }
  end
end
