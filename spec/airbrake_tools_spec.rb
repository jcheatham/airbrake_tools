require 'yaml'
require 'airbrake_tools'

ROOT = File.expand_path('../../', __FILE__)

describe "airbrake-tools" do
  before { Dir.chdir ROOT }

  describe "CLI" do
    def run(command, options={})
      result = `#{command} 2>&1`
      message = (options[:fail] ? "SUCCESS BUT SHOULD FAIL" : "FAIL")
      raise "[#{message}] #{result} [#{command}]" if $?.success? == !!options[:fail]
      result
    end

    def airbrake_tools(args, options={})
      run "#{ROOT}/bin/airbrake-tools #{args}", options
    end

    let(:config) { YAML.load(File.read("spec/fixtures.yml")) }

    describe "basics" do
      it "shows its usage without arguments" do
        airbrake_tools("", :fail => true).should include("Usage")
      end

      it "shows its usage with -h" do
        airbrake_tools("-h").should include("Usage")
      end

      it "shows its usage with --help" do
        airbrake_tools("--help").should include("Usage")
      end

      it "shows its version with -v" do
        airbrake_tools("-v").should =~ /^airbrake-tools \d+\.\d+\.\d+$/
      end

      it "shows its version with --version" do
        airbrake_tools("-v").should =~ /^airbrake-tools \d+\.\d+\.\d+$/
      end
    end

    describe "hot" do
      it "kinda works" do
        output = airbrake_tools("#{config["subdomain"]} #{config["auth_token"]} hot")
        output.should =~ /#\d+\s+\d+\.\d+\/hour\s+total:\d+/
      end
    end

    describe "list" do
      it "kinda works" do
        output = airbrake_tools("#{config["subdomain"]} #{config["auth_token"]} list")
        output.should include("Page 1 ")
        output.should =~ /^\d+/
      end
    end

    describe "summary" do
      it "kinda works" do
        output = airbrake_tools("#{config["subdomain"]} #{config["auth_token"]} summary 51344729")
        output.should include("last retrieved notice: ")
        output.should include("last 2 hours: ")
      end
    end

    describe "new" do
      it "kinda works" do
        output = airbrake_tools("#{config["subdomain"]} #{config["auth_token"]} new")
        output.should =~ /#\d+\s+\d+\.\d+\/hour\s+total:\d+/
      end
    end
  end

  describe ".extract_options" do
    it "finds nothing" do
      AirbrakeTools.send(:extract_options, []).should == {}
    end

    it "finds pages" do
      AirbrakeTools.send(:extract_options, ["--pages", "1"]).should == {:pages => 1}
    end

    it "finds env" do
      AirbrakeTools.send(:extract_options, ["--environment", "xx"]).should == {:env => "xx"}
    end

    it "finds compare-depth" do
      AirbrakeTools.send(:extract_options, ["--compare-depth", "1"]).should == {:compare_depth => 1}
    end
  end

  describe ".frequency" do
    it "calculates for 0" do
      AirbrakeTools.send(:frequency, [], 0).should == 0
      AirbrakeTools.send(:frequency, [], 1).should == 0
    end

    it "calculates for 1" do
      AirbrakeTools.send(:frequency, [stub(:created_at => Time.now - (60*60))], 1).should == 1
    end

    it "calculates for n" do
      # 3 per minute => 180/hour
      AirbrakeTools.send(:frequency, [stub(:created_at => Time.now-60), stub(:created_at => Time.now-40), stub(:created_at => Time.now-20)], 3).should == 180
    end

    it "calculates low if notices are smaller then expected notices" do
      AirbrakeTools.send(:frequency, [stub(:created_at => Time.now)], 10).should == 1
    end
  end

  describe ".select_env" do
    it "kicks out errors with wrong env" do
      AirbrakeTools.send(:select_env, [stub(:rails_env => "master")], {}).should == []
    end

    it "keeps errors if they match given env" do
      AirbrakeTools.send(:select_env, [stub(:rails_env => "master")], :env => "master").size.should == 1
    end

    it "keeps errors with right env" do
      AirbrakeTools.send(:select_env, [stub(:rails_env => "production")], {}).size.should == 1
    end
  end
end

