require 'spec_helper'
require 'fileutils'

describe Entangler::Executor do
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

  describe 'strip base path' do
    it 'should leave the leading slash' do
      executor = Entangler::Executor::Base.new('.')
      expect(executor.strip_base_path(File.absolute_path('./test/path'))).to eq '/test/path'
    end

    it 'should return the same string when prepending then stripping' do
      executor = Entangler::Executor::Base.new('.')
      expect(executor.strip_base_path(executor.generate_abs_path('/test/path'))).to eq '/test/path'
    end
  end

  describe 'generate abs path' do
    it 'should leave generate the abs path' do
      executor = Entangler::Executor::Base.new('.')
      expect(executor.generate_abs_path('/test/path')).to eq File.absolute_path('./test/path')
    end

    it 'should return the same string when stripping then prepending' do
      executor = Entangler::Executor::Base.new('.')
      path = File.absolute_path('./test/path')
      expect(executor.generate_abs_path(executor.strip_base_path(path))).to eq path
    end
  end
end
