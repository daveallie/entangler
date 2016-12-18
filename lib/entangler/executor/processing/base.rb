require_relative 'base_components/new_changes'
require_relative 'base_components/local_changes'
require_relative 'base_components/entangled_files'

module Entangler
  module Executor
    module Processing
      module Base
        include Entangler::Executor::Processing::BaseComponents::NewChanges,
                Entangler::Executor::Processing::BaseComponents::LocalChanges,
                Entangler::Executor::Processing::BaseComponents::EntangledFiles

        private

        def log_folder_list(action, folders)
          folder_list = folders.map { |c| "#{c[0][1..-1]}/" }.join("\n")
          logger.debug("#{action} #{folder_list.length} folder/s from remote:\n#{folder_list}")
        end

        def each_entry(path)
          Dir.entries(path).each do |f|
            next if ['.', '..'].include? f
            f_path = File.join(path, f)
            yield(f, f_path)
          end
        end
      end
    end
  end
end
