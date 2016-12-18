module Entangler
  module Executor
    module Processing
      module Base
        protected

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

        def process_new_changes(content)
          log_folder_list('RECIEVING', content)

          actions = initialize_actions
          content.each do |base, changes|
            process_changes_list(actions, base, changes)
          end
          process_finalised_actions(actions)

          # Keep waiting until the remote returns if there are files being updated
          @notify_sleep = Time.now.to_f + 0.5 unless actions[:update_files].any?
        end

        def process_entangled_files(content)
          logger.debug("UPDATING #{content.length} entangled file/s from remote")
          completed_files, updated_files = content.partition(&:done?)

          export_entangled_files(completed_files)
          update_entangled_files(updated_files)
          @notify_sleep = Time.now.to_f + 0.5 if completed_files.any?
        end

        def process_lines(lines)
          paths = remove_recently_exported_paths(lines.map { |line| line[2..-1] })
          to_process = paths_to_process(paths)

          return unless to_process.any?
          log_folder_list('PROCESSING', to_process)
          send_to_remote(type: :new_changes, content: to_process)
        end

        private

        def initialize_actions
          {
            created_dirs: [],
            remove_dirs: [],
            remove_files: [],
            update_files: []
          }
        end

        def num_actions_to_process(actions)
          (actions[:remove_files] + actions[:remove_dirs] + actions[:update_files]).length
        end

        def process_changes_list(actions, base, changes)
          actions[:create_dirs] = changes[:dirs].clone
          actions[:create_files] = changes[:files].keys.clone

          create_dir_if_required(generate_abs_path(base))
          generate_actions(actions, base, changes)
          process_create_dirs_and_files(actions, base)
        end

        def create_dir_if_required(full_base_path)
          return if File.directory?(full_base_path)
          FileUtils.mkdir_p(full_base_path)
          @notify_sleep = Time.now.to_i + 60
        end

        def generate_actions(actions, base, changes)
          full_base_path = generate_abs_path(base)

          each_entry(full_base_path) do |f, full_path|
            if File.directory?(full_path)
              generate_dir_actions(actions, changes, f, full_path)
            elsif changes[:files].key?(f)
              generate_file_actions(actions, changes, f, full_path)
            else
              actions[:remove_files] << full_path
            end
          end
        end

        def process_create_dirs_and_files(actions, base)
          @notify_sleep = Time.now.to_i + 60 if actions[:create_dirs].any?
          process_create_dirs(actions)
          actions[:update_files] += actions[:create_files].map { |f| File.join(base, f) }
        end

        def generate_dir_actions(actions, changes, f, full_path)
          actions[:create_dirs] -= [f]
          return if changes[:dirs].include?(f)
          actions[:remove_dirs] << full_path
        end

        def generate_file_actions(actions, changes, f, full_path)
          actions[:create_files] -= [f]
          path_mod_time = [File.size(full_path), File.mtime(full_path).to_i]
          return if changes[:files][f] == path_mod_time
          actions[:update_files] << File.join(base, f)
        end

        def process_finalised_actions(actions)
          return unless num_actions_to_process(actions) > 0
          # Prevent other tasks from running while we're updating
          @notify_sleep = Time.now.to_i + 60
          process_remove_files(actions)
          process_remove_dirs(actions)
          process_update_files(actions)
        end

        def process_create_dirs(actions)
          return unless actions[:create_dirs].any?
          full_path = generate_abs_path(base)
          dirs_to_create = actions[:create_dirs].map { |d| File.join(full_path, d) }
          logger.debug("Creating #{dirs_to_create.length} dirs")
          FileUtils.mkdir_p dirs_to_create
          actions[:created_dir] += dirs_to_create
        end

        def process_remove_files(actions)
          return unless actions[:remove_files].any?
          logger.debug("DELETING #{actions[:remove_files].length} files")
          FileUtils.rm actions[:remove_files]
        end

        def process_remove_dirs(actions)
          return unless actions[:remove_dirs].any?
          logger.debug("DELETING #{actions[:remove_dirs].length} dirs")
          FileUtils.rm_r actions[:remove_dirs]
        end

        def process_update_files(actions)
          return unless actions[:update_files].any?
          logger.debug("CREATING #{actions[:update_files].length} new entangled file/s")
          entangled_files = actions[:update_files].map { |f| Entangler::EntangledFile.new(f) }
          send_to_remote(type: :entangled_files, content: entangled_files)
        end

        def export_entangled_files(files)
          return unless files.any?
          @exported_at = Time.now.to_f
          @exported_folders = files.map { |ef| "#{File.dirname(generate_abs_path(ef.path))}/" }.uniq
          files.each(&:export)
        end

        def update_entangled_files(files)
          files.select! { |f| f.state != 1 || f.file_exists? }
          send_to_remote(type: :entangled_files, content: files) if files.any?
        end

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
