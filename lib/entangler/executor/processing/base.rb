module Entangler
  module Executor
    module Processing
      module Base
        protected
        def generate_file_list(path)
          dirs = []
          files = {}

          Dir.entries(path).each do |f|
            next if ['.', '..'].include? f
            f_path = File.join(path, f)
            if File.directory? f_path
              dirs << f
            else
              files[f] = [File.size(f_path), File.mtime(f_path).to_i]
            end
          end

          {dirs: dirs, files: files}
        end

        def process_new_changes(content)
          logger.debug("RECIEVING #{content.length} folder/s from remote:\n#{content.map{|c| "#{c[0][1..-1]}/"}.join("\n")}")

          created_dirs = []
          dirs_to_remove = []
          files_to_remove = []
          files_to_update = []

          content.each do |base, changes|
            possible_creation_dirs = changes[:dirs].clone
            possible_creation_files = changes[:files].keys.clone
            full_base_path = generate_abs_path(base)

            unless File.directory?(full_base_path)
              FileUtils::mkdir_p(full_base_path)
              @notify_sleep = Time.now.to_i + 60
            end

            Dir.entries(full_base_path).each do |f|
              next if ['.', '..'].include? f
              full_path = File.join(generate_abs_path(base), f)
              if File.directory?(full_path)
                possible_creation_dirs -= [f]
                dirs_to_remove << full_path unless changes[:dirs].include?(f)
              elsif changes[:files].has_key?(f)
                possible_creation_files -= [f]
                files_to_update << File.join(base, f) unless changes[:files][f] == [File.size(full_path), File.mtime(full_path).to_i]
              else
                files_to_remove << full_path
              end
            end

            dirs_to_create = possible_creation_dirs.map{|d| File.join(generate_abs_path(base), d)}
            if dirs_to_create.any?
              logger.debug("Creating #{dirs_to_create.length} dirs")
              @notify_sleep = Time.now.to_i + 60
              FileUtils.mkdir_p dirs_to_create
            end
            created_dirs += dirs_to_create
            files_to_update += possible_creation_files.map{|f| File.join(base, f)}
          end

          @notify_sleep = Time.now.to_i + 60 if (files_to_remove + created_dirs + dirs_to_remove + files_to_update).any?

          if files_to_remove.any?
            logger.debug("DELETING #{files_to_remove.length} files")
            FileUtils.rm files_to_remove
          end
          if dirs_to_remove.any?
            logger.debug("DELETING #{dirs_to_remove.length} dirs")
            FileUtils.rm_r dirs_to_remove
          end
          if files_to_update.any?
            logger.debug("CREATING #{files_to_update.length} new entangled file/s")
            send_to_remote(type: :entangled_files, content: files_to_update.map{|f| Entangler::EntangledFile.new(f) })
          end
          @notify_sleep = Time.now.to_f + 0.5 if (files_to_remove + created_dirs + dirs_to_remove + files_to_update).any?
          @notify_sleep += 60 if files_to_update.any?
        end

        def process_entangled_files(content)
          logger.debug("UPDATING #{content.length} entangled file/s from remote")
          completed_files, updated_files = content.partition(&:done?)

          if completed_files.any?
            @exported_at = Time.now.to_f
            @exported_folders = completed_files.map{|ef| "#{File.dirname(generate_abs_path(ef.path))}/" }.uniq
            completed_files.each(&:export)
          end

          updated_files = updated_files.find_all{|f| f.state != 1 || f.file_exists? }
          if updated_files.any?
            send_to_remote(type: :entangled_files, content: updated_files)
          end
          @notify_sleep = Time.now.to_f + 0.5 if completed_files.any?
        end

        def process_lines(lines)
          paths = lines.map{|line| line[2..-1] }

          if @exported_at < Time.now.to_f && Time.now.to_f < @exported_at + 2
            paths -= @exported_folders
          end

          to_process = paths.map do |path|
            stripped_path = strip_base_path(path)
            next unless @opts[:ignore].nil? || @opts[:ignore].none?{|i| stripped_path.match(i) }
            next unless File.directory?(path)

            [stripped_path, generate_file_list(path)]
          end.compact.sort_by(&:first)

          return unless to_process.any?
          logger.debug("PROCESSING #{to_process.count} folder/s:\n#{to_process.map{|c| "#{c[0][1..-1]}/"}.join("\n")}")
          send_to_remote(type: :new_changes, content: to_process)
        end
      end
    end
  end
end
