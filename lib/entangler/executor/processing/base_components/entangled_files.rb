module Entangler
  module Executor
    module Processing
      module BaseComponents
        module EntangledFiles
          protected

          def process_entangled_files(content)
            logger.debug("UPDATING #{content.length} entangled file/s from remote")
            completed_files, updated_files = content.partition(&:done?)

            export_entangled_files(completed_files)
            update_entangled_files(updated_files)
            @notify_sleep = Time.now.to_f + 0.5 if completed_files.any?
          end

          private

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
        end
      end
    end
  end
end
