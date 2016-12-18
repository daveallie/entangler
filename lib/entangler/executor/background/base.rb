module Entangler
  module Executor
    module Background
      module Base
        protected

        def wait_for_threads
          @consumer_thread.join
          @remote_io_thread.join
          @local_io_thread.join
          Process.wait @notify_daemon_pid
        end

        def kill_off_threads
          begin
            Process.kill('TERM', @notify_daemon_pid)
          rescue
            nil
          end
          @consumer_thread.terminate
          @remote_io_thread.terminate
          @local_io_thread.terminate
        end

        def start_notify_daemon
          logger.info('starting notify daemon')
          r, w = IO.pipe
          @notify_daemon_pid = spawn(start_notify_daemon_cmd, out: w)
          w.close
          @notify_reader = r
        end

        def start_remote_io
          logger.info('starting remote IO')
          @remote_io_thread = Thread.new do
            with_kill_threads_rescue do
              loop do
                msg = Marshal.load(@remote_reader)
                process_next_remote_line(msg)
              end
            end
          end
        end

        def start_local_io
          logger.info('starting local IO')
          @local_action_queue = Queue.new
          @local_io_thread = Thread.new do
            with_kill_threads_rescue do
              loop do
                ready = IO.select([@notify_reader]).first || []
                break unless process_next_local_line(ready)
              end
            end
          end
        end

        def start_local_consumer
          @consumer_thread = Thread.new do
            loop do
              msg = []
              collect_local_actions_until_empty(msg)
              collect_local_actions_until_can_notify(msg)
              process_lines(msg.uniq)
              sleep 0.5
            end
          end
        end

        def start_notify_daemon_cmd
          uname = `uname`.strip.downcase
          raise 'Unsupported OS' unless %w(darwin linux).include?(uname)

          lib_dir = File.dirname(File.dirname(File.dirname(File.dirname(__FILE__))))
          "#{File.join(lib_dir, 'notifier', 'bin', uname, 'notify')} #{base_dir}"
        end

        private

        # returns false if processing should stop, true otherwise
        def process_next_local_line(ready)
          return true unless ready.any?
          return false if ready.first.eof?
          line = ready.first.gets
          return true if line.nil? || line.empty?
          line = line.strip
          return true if line == '-'
          @local_action_queue.push line
          true
        end

        def process_next_remote_line(msg)
          return if msg.nil?

          case msg[:type]
          when :new_changes
            process_new_changes(msg[:content])
          when :entangled_files
            process_entangled_files(msg[:content])
          end
        end

        def collect_local_actions_until_empty(msgs)
          loop do
            msgs += all_local_actions
            sleep 0.2
            break if @local_action_queue.empty?
          end
        end

        def collect_local_actions_until_can_notify(msgs)
          while Time.now.to_f <= @notify_sleep
            sleep 0.5
            msgs += all_local_actions
          end
        end

        def all_local_actions
          actions = []
          actions << @local_action_queue.pop until @local_action_queue.empty?
          actions
        end

        def with_kill_threads_rescue
          yield
        rescue => e
          $stderr.puts e.message
          $stderr.puts e.backtrace.join("\n")
          kill_off_threads
        end
      end
    end
  end
end
