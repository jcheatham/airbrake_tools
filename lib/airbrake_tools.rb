# encoding: UTF-8
require "airbrake_tools/version"
require "airbrake_tools/png_grapher"
require "airbrake-api"

module AirbrakeTools
  DEFAULT_HOT_PAGES = 1
  DEFAULT_NEW_PAGES = 1
  DEFAULT_SUMMARY_PAGES = 5
  DEFAULT_COMPARE_DEPTH = 7
  DEFAULT_ENVIRONMENT = "production"

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
        print_errors(hot(options))
      when "list"
        list(options)
      when "summary"
        summary(ARGV[3] || raise("Need error id"), options)
      when "new"
        print_errors(new(options))
      else
        raise "Unknown command #{ARGV[2].inspect} try hot/new/list/summary"
      end
      return 0
    end

    def hot(options = {})
      errors = errors_with_notices({:pages => DEFAULT_HOT_PAGES}.merge(options))
      errors.sort_by{|e,n,f| f }.reverse
    end

    def new(options = {})
      errors = errors_with_notices({:pages => DEFAULT_NEW_PAGES}.merge(options))
      errors.sort_by{|e,n,f| e.created_at }.reverse
    end

    def errors_with_notices(options)
      add_notices_to_pages(errors_from_pages(options))
    end

    def list(options)
      page = 1
      while errors = AirbrakeAPI.errors(:page => page)
        select_env(errors, options).each do |error|
          puts "#{error.id} -- #{error.error_class} -- #{error.error_message} -- #{error.created_at}"
        end
        $stderr.puts "Page #{page} ----------\n"
        page += 1
      end
    end

    def summary(error_id, options)
      compare_depth = options[:compare_depth] || DEFAULT_COMPARE_DEPTH
      notices = AirbrakeAPI.notices(error_id, :pages => options[:pages] || DEFAULT_SUMMARY_PAGES)

      puts "last retrieved notice: #{((Time.now - notices.last.created_at) / (60 * 60)).round} hours ago at #{notices.last.created_at}"
      puts "last 2 hours:  #{sparkline(notices, :slots => 60, :interval => 120)}"
      puts "last day:      #{sparkline(notices, :slots => 24, :interval => 60 * 60)}"

      backtraces = notices.compact.select{|n| n.backtrace }.group_by do |notice|
        if notice.backtrace.is_a?(String) # no backtrace recorded...
          []
        else
          notice.backtrace.first[1][0..compare_depth]
        end
      end

      backtraces.sort_by{|_,notices| notices.size }.reverse.each_with_index do |(backtrace, notices), index|
        puts "Trace #{index + 1}: occurred #{notices.size} times e.g. #{notices[0..5].map(&:id).join(", ")}"
        puts notices.first.error_message
        puts backtrace.map{|line| line.sub("[PROJECT_ROOT]/", "./") }
        puts ""
      end
    end

    private

    def add_notices_to_pages(errors)
      Parallel.map(errors, :in_threads => 10) do |error|
        begin
          pages = 1
          notices = AirbrakeAPI.notices(error.id, :pages => pages, :raw => true).compact
          print "."
          [error, notices, frequency(notices, pages * AirbrakeAPI::Client::PER_PAGE)]
        rescue Faraday::Error::ParsingError
          $stderr.puts "Ignoring #{error_summary(error)}, got 500 from http://#{AirbrakeAPI.account}.airbrake.io/errors/#{error.id}"
        end
      end.compact
    end

    def errors_from_pages(options)
      errors = []
      options[:pages].times do |i|
        errors.concat(AirbrakeAPI.errors(:page => i+1) || [])
      end
      select_env(errors, options)
    end

    def select_env(errors, options)
      errors.select{|e| e.rails_env == (options[:env] || DEFAULT_ENVIRONMENT) }
    end

    def print_errors(errors)
      errors.each_with_index do |(error, notices, rate, deviance), index|
        puts "\n##{(index+1).to_s.ljust(2)} #{rate.round(2).to_s.rjust(6)}/hour total:#{error.notices_count.to_s.ljust(8)} #{sparkline(notices, :slots => 60, :interval => 60).ljust(61)} -- #{error_summary(error)}"
      end
    end

    # we only have a limited sample size, so we do not know how many errors occurred in total
    def frequency(notices, expected_notices)
      return 0 if notices.empty?
      range = if notices.size < expected_notices
        60 * 60 # we got less notices then we wanted -> very few errors -> low frequency
      else
        Time.now - notices.map{ |n| n.created_at }.min
      end
      errors_per_second = notices.size / range.to_f
      (errors_per_second * 60 * 60).round(2) # errors_per_hour
    end

    def error_summary(error)
      "id:#{error.id} -- first:#{error.created_at} -- #{error.error_class} -- #{error.error_message}"
    end

    def extract_options(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(" "*12, "")
            Power tools for airbrake.

            hot: list hottest errors
            list: list errors 1-by-1 so you can e.g. grep -> search
            summary: analyze occurrences and backtrace origins

            Usage:
                airbrake-tools subdomain auth-token command [options]
                  auth-token: go to airbrake -> settings, copy your auth-token

            Options:
        BANNER
        opts.on("-c NUM", "--compare-depth NUM", Integer, "How deep to compare backtraces in summary (default: #{DEFAULT_COMPARE_DEPTH})") {|s| options[:compare_depth] = s }
        opts.on("-p NUM", "--pages NUM", Integer, "How maybe pages to iterate over (default: hot:#{DEFAULT_HOT_PAGES} new:#{DEFAULT_NEW_PAGES} summary:#{DEFAULT_SUMMARY_PAGES})") {|s| options[:pages] = s }
        opts.on("-e ENV", "--environment ENV", String, "Only show errors from this environment (default: #{DEFAULT_ENVIRONMENT})") {|s| options[:env] = s }
        opts.on("-g", "--graph", "Generate a PNG graph per error") {|s| options[:graph] = true }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts "airbrake-tools #{VERSION}"; exit }
      end.parse!(argv)
      options
    end

    def bucketize_notice_frequency(notices, num_buckets=60, range_left=nil, range_right=nil)
      range_left ||= notices.first.created_at
      range_right ||= notices.last.created_at + 1
      interval = (range_left - range_right) / num_buckets
      buckets = Array.new(num_buckets, 0)
      notices.each{|n| buckets[((range_left - n.created_at) / interval)] += 1 if n.created_at > range_right }
      buckets
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
