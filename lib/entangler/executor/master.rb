require_relative 'background/master'

module Entangler
  module Executor
    class Master < Base
      include Entangler::Executor::Background::Master

      def run
        perform_initial_rsync
        sleep 1
        start_remote_slave
        super
        @remote_writer.close
        @remote_reader.close
      end

      private
      def validate_opts
        super
        if @opts[:remote_mode]
          raise 'Missing remote base dir' unless @opts.keys.include?(:remote_base_dir)
          raise 'Missing remote user' unless @opts.keys.include?(:remote_user)
          raise 'Missing remote host' unless @opts.keys.include?(:remote_host)
          @opts[:remote_port] ||= '22'
          res = `ssh -q #{@opts[:remote_user]}@#{@opts[:remote_host]} -p #{@opts[:remote_port]} -C "[[ -d '#{@opts[:remote_base_dir]}' ]] && echo 'ok' || echo 'missing'"`
          raise 'Cannot connect to remote' if res.empty?
          raise 'Remote base dir invalid' unless res.strip == 'ok'
        else
          @opts[:remote_base_dir] = File.realpath(File.expand_path(@opts[:remote_base_dir]))
          raise "Destination directory can't be the same as the base directory" if @opts[:remote_base_dir] == self.base_dir
          raise "Destination directory doesn't exist" unless Dir.exists?(@opts[:remote_base_dir])
        end
      end

      def perform_initial_rsync
        logger.info 'Running initial sync'
        all_folders = Dir.glob("#{base_dir}/**/*/", File::FNM_DOTMATCH).tap{|a| a.shift(1) }.find_all{|path| !path.end_with?("/./")}
        all_ignore_matches = all_folders.map{|path| @opts[:ignore].map{|regexp| regexp.match("/#{path[0..-2]}")}.compact.first}.compact
        exclude_folders = all_ignore_matches.map{|match| match[0]}.uniq.map{|path| path[1..-1]}
        exclude_args = exclude_folders.map{|path| "--exclude #{path}"}.join(' ')

        ssh_settings = @opts[:remote_mode] ? "-e \"ssh -p #{@opts[:remote_port]}\"" : ''
        remote_path = @opts[:remote_mode] ? "#{@opts[:remote_user]}@#{@opts[:remote_host]}:#{@opts[:remote_base_dir]}/" : "#{@opts[:remote_base_dir]}/"

        rsync_cmd = "rsync -azv #{exclude_args} #{ssh_settings} --delete #{base_dir}/ #{remote_path}"

        IO.popen(rsync_cmd).each do |line|
          logger.debug line.chomp
        end
        logger.debug 'Initial sync complete'
      end
    end
  end
end
