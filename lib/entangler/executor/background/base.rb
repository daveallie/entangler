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
            begin
              loop do
                msg = Marshal.load(@remote_reader)
                next if msg.nil?

                case msg[:type]
                when :new_changes
                  process_new_changes(msg[:content])
                when :entangled_files
                  process_entangled_files(msg[:content])
                end
              end
            rescue => e
              $stderr.puts e.message
              $stderr.puts e.backtrace.join("\n")
              kill_off_threads
            end
          end
        end

        def start_local_io
          logger.info('starting local IO')
          @local_action_queue = Queue.new
          @local_io_thread = Thread.new do
            begin
              loop do
                ready = IO.select([@notify_reader]).first
                next unless ready && ready.any?
                break if ready.first.eof?
                line = ready.first.gets
                next if line.nil? || line.empty?
                line = line.strip
                next if line == '-'
                @local_action_queue.push line
              end
            rescue => e
              $stderr.puts e.message
              $stderr.puts e.backtrace.join("\n")
              kill_off_threads
            end
          end
        end

        def start_local_consumer
          @consumer_thread = Thread.new do
            loop do
              msg = [@local_action_queue.pop]
              loop do
                sleep 0.2
                break if @local_action_queue.empty?
                msg << @local_action_queue.pop until @local_action_queue.empty?
              end
              while Time.now.to_f <= @notify_sleep
                sleep 0.5
                msg << @local_action_queue.pop until @local_action_queue.empty?
              end
              process_lines(msg.uniq)
              msg = []
              sleep 0.5
            end
          end
        end

        def start_notify_daemon_cmd
          uname = `uname`.strip.downcase
          raise 'Unsupported OS' unless %w(darwin linux).include?(uname)

          "#{File.join(File.dirname(File.dirname(File.dirname(File.dirname(__FILE__)))), 'notifier', 'bin', uname, 'notify')} #{base_dir}"
        end
      end
    end
  end
end
