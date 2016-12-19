require 'listen'
require 'entangler/entangled_file'

module Entangler
  module Executor
    module Background
      module Base
        protected

        def start_listener
          logger.info('starting listener')
          listener.start
        end

        def stop_listener
          listener.stop
        end

        def start_remote_io
          logger.info('starting remote IO')
          @remote_io_thread = Thread.new do
            with_kill_threads_rescue do
              loop do
                msg = Marshal.load(@remote_reader)
                process_remote_changes(msg)
              end
            end
          end
        end

        def wait_for_threads
          @remote_io_thread.join
        end

        def kill_off_threads
          @remote_io_thread.terminate
        end

        private

        def listener
          @listener ||= begin
            l = Listen::Listener.new(base_dir) do |modified, added, removed|
              process_local_changes(generate_entangled_files(added, :create) +
                                        generate_entangled_files(modified, :update) +
                                        generate_entangled_files(removed, :delete))
            end
            l.ignore!(@opts[:ignore])
            l
          end
        end

        def generate_entangled_files(paths, action)
          paths.map { |path| Entangler::EntangledFile.new(action, strip_base_path(path)) }
        end

        def remove_recently_changed_files(entangled_files)
          return entangled_files if @last_changed_at + 2 < Time.now.to_f
          entangled_files.find_all { |ef| @changed_files.include?(ef.path) }
        end

        def process_local_changes(changes)
          with_listener_pause(0) do
            changes = remove_recently_changed_files(changes)
            send_to_remote(changes) if changes.any?
          end
        end

        def process_remote_changes(changes)
          return if changes.nil?
          changes.each(&:process)
          @last_changed_at = Time.now.to_f
          @changed_files = changes.map(&:path)
        end

        def with_kill_threads_rescue
          yield
        rescue => e
          $stderr.puts e.message
          $stderr.puts e.backtrace.join("\n")
          kill_off_threads
        end

        def with_listener_pause(idx)
          @listener_pauses[idx] = true
          listener.pause
          yield
          @listener_pauses[idx] = false
          listener.unpause if @listener_pauses.none?
        end
      end
    end
  end
end
