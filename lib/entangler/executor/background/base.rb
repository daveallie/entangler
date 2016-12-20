require 'listen'
require 'entangler/entangled_file'
require 'to_regexp'

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
            listen_ignores = @opts[:ignore].map do |regexp|
              if regexp.inspect.start_with? '/^'
                "/^#{base_dir}/#{regexp.inspect[2..-1]}".to_regexp(detect: true)
              else
                regexp
              end
            end

            Listen::Listener.new(base_dir, ignore!: listen_ignores) do |modified, added, removed|
              process_local_changes(generate_entangled_files(added, :create) +
                                        generate_entangled_files(modified, :update) +
                                        generate_entangled_files(removed, :delete))
            end
          end
        end

        def generate_entangled_files(paths, action)
          paths.map { |path| Entangler::EntangledFile.new(action, strip_base_path(path)) }
        end

        def remove_recently_changed_files(entangled_files)
          @recently_received_paths.select! { |_, time| Time.now.to_f < time + 0.5 }
          paths = @recently_received_paths.map(&:first)
          entangled_files.reject { |ef| paths.include?(ef.path) }
        end

        def process_local_changes(changes)
          with_listener_pause(0) do
            changes = remove_recently_changed_files(changes)
            if changes.any?
              logger.info("PROCESSING #{changes.length} local changes")
              logger.debug(changes.map(&:path).join("\n"))
              send_to_remote(changes)
            end
          end
        end

        def process_remote_changes(changes)
          with_listener_pause(1) do
            return if changes.nil?
            logger.info("PROCESSING #{changes.length} remote changes")
            logger.debug(changes.map(&:path).join("\n"))
            changes.each(&:process)
            update_recently_received_paths(changes)
          end
        end

        def update_recently_received_paths(changes)
          changes.each do |change|
            index = @recently_received_paths.index { |path, _| path == change.path }
            if index.nil?
              @recently_received_paths << [change.path, Time.now.to_f]
            else
              @recently_received_paths[index][1] = Time.now.to_f
            end
          end
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
          listener.start if @listener_pauses.none?
        end
      end
    end
  end
end
