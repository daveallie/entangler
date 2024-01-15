# frozen_string_literal: true

require 'spec_helper'

describe Entangler::Executor::Master do
  describe 'validation' do
    it "is invalid if the remote directory doesn't exist" do
      with_temp_dir do |dir|
        expect { described_class.new(dir, remote_base_dir: File.join(dir, 'asdf')) }.to(
          raise_error(Entangler::ValidationError, "Destination directory doesn't exist")
        )
      end
    end

    it 'is invalid if the remote directory is a file' do
      with_temp_dir do |dir|
        File.write(File.join(dir, 'asdf'), 'w') { |f| f.write('asdf') }
        expect { described_class.new(dir, remote_base_dir: File.join(dir, 'asdf')) }.to(
          raise_error(Entangler::ValidationError, 'Destination directory is a file')
        )
      end
    end

    it 'is invalid if the local and remote directory are the same' do
      with_temp_dir do |dir|
        expect { described_class.new(dir, remote_base_dir: dir) }.to(
          raise_error(Entangler::ValidationError, "Destination directory can't be the same as the base directory")
        )
      end
    end
  end
end
