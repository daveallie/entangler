require_relative 'base_components/thread_control'

module Entangler
  module Executor
    module Background
      module Base
        include Entangler::Executor::Background::BaseComponents::ThreadControl

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
      end
    end
  end
end
