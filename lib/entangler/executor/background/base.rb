# frozen_string_literal: true

require 'listen'
require 'entangler/entangled_file'
require 'benchmark'

module Entangler
  module Executor
    module Background
      module Base
        protected

        def start_listener
          logger.info('Starting - Local file watcher')
          listener.start
        end

        def stop_listener
          listener.stop
        end

        def start_remote_io
          logger.info('Starting - Remote communications')
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
            Listen::Listener.new(base_dir, ignore!: @opts[:ignore]) do |modified, added, removed|
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
          logger.debug("Skipping paths #{paths.join(', ')} as they have changed recently") if paths.any?
          entangled_files.reject { |ef| paths.include?(ef.path) }
        end

        def process_local_changes(changes)
          with_listener_pause(0) do
            changes = remove_recently_changed_files(changes)
            if changes.any?
              logger.info("Processing - #{changes.length} local changes")
              logger.debug("File List:\n#{changes.map(&:path).join("\n")}")
              with_log_time("Completed - #{changes.length} local changes") do
                send_to_remote(changes)
              end
            end
          end
        end

        def process_remote_changes(changes)
          with_listener_pause(1) do
            return if changes.nil?

            logger.info("Processing - #{changes.length} remote changes")
            logger.debug("File List:\n#{changes.map(&:path).join("\n")}")
            with_log_time("Completed - #{changes.length} remote changes") do
              changes.each(&:process)
              update_recently_received_paths(changes)
            end
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
        rescue StandardError => e
          warn e.message
          warn e.backtrace.join("\n")
          kill_off_threads
        end

        def with_listener_pause(idx)
          @listener_pauses[idx] = true
          listener.pause
          yield
        ensure
          @listener_pauses[idx] = false
          listener.start if @listener_pauses.none?
        end

        def with_log_time(msg)
          res = nil
          time = Benchmark.realtime do
            res = yield
          end
          logger.debug("#{msg} in #{time * 1000}ms")
          res
        end
      end
    end
  end
end
