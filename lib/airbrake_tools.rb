require "airbrake_tools/version"

module AirbrakeTools
  class << self
    def cli(argv)
      options = extract_options(argv)

      subdomain, key = argv
      if subdomain.to_s.empty? || key.to_s.empty?
        puts "Usage instructions: airbrake-tools --help"
        return 1
      end

      hot(subdomain, key, options) || 0
    end

    def hot(subdomain, key, options)
      puts "Calling hot with #{subdomain}, #{key}, #{options.inspect}"
      return 0
    end

    private

    def extract_options(argv)
      options = {
      }
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(" "*12, "")
            Get the hotest airbrake errors

            Usage:
                airbrake-tools subdomain key [options]

            Options:
        BANNER
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts "airbrake-tools #{VERSION}"; exit }
      end.parse!(argv)
      options
    end

    def run(cmd)
      all = ""
      puts cmd
      IO.popen(cmd) do |pipe|
        while str = pipe.gets
          all << str
          puts str
        end
      end
      [$?.success?, all]
    end

    def run!(command)
      raise "Command failed #{command}" unless run(command).first
    end
  end
end
