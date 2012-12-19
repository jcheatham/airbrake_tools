# encoding: UTF-8
require "airbrake_tools/version"
require "airbrake-api"

module AirbrakeTools
  class << self
    def cli(argv)
      options = extract_options(argv)

      AirbrakeAPI.account = ARGV[0]
      AirbrakeAPI.auth_token = ARGV[1]
      AirbrakeAPI.secure = true

      if AirbrakeAPI.account.to_s.empty? || AirbrakeAPI.auth_token.to_s.empty?
        puts "Usage instructions: airbrake-tools --help"
        return 1
      end

      case ARGV[2]
      when "hot"
        errors = hot(options)
        print_errors(errors)
      when "list"
        list(options)
      else
        raise "Unknown command try hot/list"
      end
      return 0
    end

    def hot(options = {})
      pages = (options[:pages] || 1).to_i
      errors = []
      pages.times do |i|
        errors.concat(AirbrakeAPI.errors(:page => i+1) || [])
      end
      select_env!(errors, options)

      errors = Parallel.map(errors, :in_threads => 10) do |error|
        begin
          notices = AirbrakeAPI.notices(error.id, :pages => 1, :raw => true).compact
          print "."
          [error, notices, frequency(notices)]
        rescue Faraday::Error::ParsingError
          $stderr.puts "Ignoring #{summary(error)}, got 500 from http://#{AirbrakeAPI.account}.airbrake.io/errors/#{error.id}"
        end
      end.compact

      errors.sort_by{|e,n,f| f }.reverse
    end

    def list(options)
      page = 1
      while errors = AirbrakeAPI.errors(:page => page)
        select_env!(errors, options)
        errors.each do |error|
          puts "#{error.id} -- #{error.error_class} -- #{error.error_message} -- #{error.created_at}"
        end
        $stderr.puts "Page #{page} ----------\n"
        page += 1
      end
    end

    private

    def select_env!(errors, options)
      errors.select!{|e| e.rails_env == options[:env] || "production" }
    end

    def print_errors(hot)
      hot.each_with_index do |(error, notices, rate, deviance), index|
        puts "\n##{(index+1).to_s.ljust(2)} #{rate.round(2).to_s.rjust(6)}/hour total:#{error.notices_count.to_s.ljust(8)} #{sparkline(notices, :slots => 60, :interval => 60).ljust(61)} -- #{summary(error)}"
      end
    end

    def frequency(notices)
      hour = 60 * 60
      sum_of_ages = notices.map { |n| Time.now - n.created_at }.inject(&:+)
      average_age = sum_of_ages / notices.size
      time_to_error = average_age / notices.size
      rate = 1 / time_to_error
      (rate * hour).round(1)
    end

    def summary(error)
      "id:#{error.id} -- first:#{error.created_at} -- #{error.error_class} -- #{error.error_message}"
    end

    def extract_options(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(" "*12, "")
            Power tools for airbrake.

            hot: list hottest errors
            list: list errors 1-by-1 so you can e.g. grep -> search

            Usage:
                airbrake-tools subdomain auth-token command [options]
                  auth-token: go to airbrake -> settings, copy your auth-token

            Options:
        BANNER
        opts.on("-e ENV", "--environment ENV", String, "Only show errors from this environment (default: production)") {|s| options[:env] = s }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts "airbrake-tools #{VERSION}"; exit }
      end.parse!(argv)
      options
    end

    def sparkline_data(notices, options)
      last = notices.last.created_at
      now = Time.now
      Array.new(options[:slots]).each_with_index.map do |_, i|
        slot_end = now - (i * options[:interval])
        slot_start = slot_end - 1 * options[:interval]
        next if last > slot_end # do not show empty lines when we actually have no data
        notices.select { |n| n.created_at.between?(slot_start, slot_end) }.size
      end
    end

    def sparkline(notices, options)
      `#{File.expand_path('../../spark.sh',__FILE__)} #{sparkline_data(notices, options).join(" ")}`.strip
    end
  end
end
