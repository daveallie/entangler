module Entangler
  module Executor
    module Processing
      module BaseComponents
        module LocalChanges
          protected

          def process_lines(lines)
            paths = remove_recently_exported_paths(lines.map { |line| line[2..-1] })
            to_process = paths_to_process(paths)

            return unless to_process.any?
            log_folder_list('PROCESSING', to_process)
            send_to_remote(type: :new_changes, content: to_process)
          end

          private

          def remove_recently_exported_paths(paths)
            return paths if @exported_at + 2 < Time.now.to_f
            paths - @exported_folders
          end

          def paths_to_process(paths)
            paths.map do |path|
              stripped_path = strip_base_path(path)
              next unless File.directory?(path)
              next unless @opts[:ignore].nil? || @opts[:ignore].none? { |i| stripped_path.match(i) }

              [stripped_path, generate_file_list(path)]
            end.compact.sort_by(&:first)
          end

          def generate_file_list(path)
            dirs = []
            files = {}

            each_entry(path) do |f, f_path|
              if File.directory? f_path
                dirs << f
              else
                files[f] = [File.size(f_path), File.mtime(f_path).to_i]
              end
            end

            { dirs: dirs, files: files }
          end
        end
      end
    end
  end
end
