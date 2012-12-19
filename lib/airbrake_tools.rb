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

      hot_errors = hot(options)
      print_errors(hot_errors)
      return 0
    end

    def hot(options = {})
      pages = (options[:pages] || 1).to_i
      errors = []
      pages.times do |i|
        errors.concat(AirbrakeAPI.errors(:page => i+1) || [])
      end
      errors.select!{|e| e.rails_env == "production" }

      errors = Parallel.map(errors, :in_threads => 10) do |error|
        begin
          notices = AirbrakeAPI.notices(error.id, :pages => 1, :raw => true).compact
          print "."
          [error, notices] + frequency(notices)
        rescue Faraday::Error::ParsingError
          $stderr.puts "Ignoring #{summary(error)}, got 500 from http://#{AirbrakeAPI.account}.airbrake.io/errors/#{error.id}"
        end
      end.compact

      errors.sort_by{|e,n,f,d| f }.reverse
    end

    def print_errors(hot)
      hot.each_with_index do |(error, notices, rate, deviance), index|
        puts "\n##{(index+1).to_s.ljust(2)} #{rate.round(2).to_s.rjust(6)}/hour ±#{deviance.round(2).to_s.ljust(5)} total:#{error.notices_count.to_s.ljust(8)} #{sparkline(notices, :slots => 60, :interval => 60).ljust(61)} -- #{summary(error)}"
      end
    end

    private

    def frequency(notices)
      mean   = notices.reduce(0){|sum,n| sum +  (Time.now - n.created_at) } / notices.size
      sqrsum = notices.reduce(0){|sum,n| sum + ((Time.now - n.created_at) - mean)**2}
      var    = sqrsum / notices.size.to_f
      stddev = Math.sqrt(var)
      [3600.0 / stddev, 3600.0 / var]
    end

    def summary(error)
      "id:#{error.id} -- first:#{error.created_at} -- #{error.error_class} -- #{error.error_message}"
    end

    def extract_options(argv)
      options = {
      }
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(" "*12, "")
            Get the hotest airbrake errors

            Usage:
                airbrake-tools subdomain token [options]
                  token: go to airbrake -> settings, copy your auth token

            Options:
        BANNER
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
