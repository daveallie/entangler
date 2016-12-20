require 'rspec'
require 'fileutils'

describe 'listen ignore generation' do
  it 'should prevent listen from notifying' do
    Dir.mktmpdir do |dir|
      f1 = File.join(dir, 'test', 'subfolder')
      f2 = File.join(dir, 'test2', 'subfolder')
      FileUtils.mkdir_p([f1, f2])
      source, *rest = 'test'.as_regexp(detect: true)
      regexp = ::Regexp.new "^#{source}(?:/[^/]+)*$", *rest

      changes = []

      l = Listen::Listener.new(dir, ignore!: [regexp]) do |add, mod, del|
        changes += add
        changes += mod
        changes += del
      end

      l.start

      sleep 1

      File.write(File.join(f1, 'file'), 'w') { |f| f.write('asdf') }
      File.write(File.join(f2, 'file'), 'w') { |f| f.write('asdf') }

      sleep 1

      l.stop

      expect(changes.length).to eq 1
      expect(changes.first).to end_with File.join(f2, 'file')
    end
  end
end
