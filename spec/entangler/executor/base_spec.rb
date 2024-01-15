# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

describe Entangler::Executor::Base do
  let(:default_ignores) do
    [
      described_class::GIT_IGNORE_REGEX,
      described_class::ENTANGLER_IGNORE_REGEX
    ]
  end

  describe 'validation' do
    it "is invalid if the base directory doesn't exist" do
      with_temp_dir do |dir|
        expect { described_class.new(File.join(dir, 'asdf')) }.to(
          raise_error(Entangler::ValidationError, "Base directory doesn't exist")
        )
      end
    end

    it 'is invalid if the base directory is a file' do
      with_temp_dir do |dir|
        File.write(File.join(dir, 'asdf'), 'w') { |f| f.write('asdf') }
        expect { described_class.new(File.join(dir, 'asdf')) }.to(
          raise_error(Entangler::ValidationError, 'Base directory is a file')
        )
      end
    end
  end

  describe 'listen ignore generation' do
    it 'prevents listen from notifying' do # rubocop:disable RSpec/MultipleExpectations
      with_temp_dir do |dir|
        f1 = File.join(dir, 'test', 'subfolder')
        f2 = File.join(dir, 'test2', 'subfolder')
        FileUtils.mkdir_p([f1, f2])
        source, *rest = 'test'.as_regexp(detect: true)
        regexp = Regexp.new "^#{source}(?:/[^/]+)*$", *rest

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

  describe 'listen force polling' do
    before do
      allow(Listen::Listener).to receive(:new).and_return(
        instance_double(Listen::Listener, start: nil, stop: nil)
      )
    end

    context 'when force polling is set' do
      it 'configures listen with the polling adapter enabled' do
        with_temp_dir do |dir|
          executor = described_class.new(dir, force_polling: true)
          executor.run
          expect(Listen::Listener).to have_received(:new).with(executor.base_dir,
                                                               ignore!: default_ignores,
                                                               force_polling: true)
        end
      end
    end

    context 'when force polling is not set' do
      it 'configures listen with the polling adapter disabled' do
        with_temp_dir do |dir|
          executor = described_class.new(dir)
          executor.run
          expect(Listen::Listener).to have_received(:new).with(executor.base_dir,
                                                               ignore!: default_ignores,
                                                               force_polling: false)
        end
      end
    end
  end

  describe 'strip base path' do
    it 'leaves the leading slash' do
      executor = described_class.new('.')
      expect(executor.strip_base_path(File.absolute_path('./test/path'))).to eq '/test/path'
    end

    it 'returns the same string when prepending then stripping' do
      executor = described_class.new('.')
      expect(executor.strip_base_path(executor.generate_abs_path('/test/path'))).to eq '/test/path'
    end
  end

  describe 'generate abs path' do
    it 'leaves generate the abs path' do
      executor = described_class.new('.')
      expect(executor.generate_abs_path('/test/path')).to eq File.absolute_path('./test/path')
    end

    it 'returns the same string when stripping then prepending' do
      executor = described_class.new('.')
      path = File.absolute_path('./test/path')
      expect(executor.generate_abs_path(executor.strip_base_path(path))).to eq path
    end
  end
end
