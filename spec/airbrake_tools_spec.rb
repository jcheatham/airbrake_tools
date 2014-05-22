require 'yaml'
require 'stringio'
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
        output = airbrake_tools("#{config["subdomain"]} #{config["auth_token"]} summary #{config["summary_error_id"]} -p 1")
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

  describe ".average_first_project_line" do
    it "is 0 for 0" do
      AirbrakeTools.send(:average_first_project_line, []).should == 0
    end

    it "is 0 for no matching line" do
      AirbrakeTools.send(:average_first_project_line, [["/usr/local/rvm/rubies/foo.rb"]]).should == 0
    end

    it "is the average of matching lines" do
      gem = "/usr/local/rvm/foo.rb:123"
      local = "[PROJECT_ROOT]/foo.rb:123"
      AirbrakeTools.send(:average_first_project_line, [
        [gem, local, local, local], # 1
        [gem, gem, gem, local, gem], # 3
        [gem, gem, gem, gem, gem, gem], # 0
      ]).should == 2
    end
  end

  describe ".custom_file?" do
    it "is custom if it's not a library" do
      AirbrakeTools.send(:custom_file?, "[PROJECT_ROOT]/app/foo.rb:123").should == true
    end

    it "is not custom if it's a system gem" do
      AirbrakeTools.send(:custom_file?, "/usr/local/rvm/foo.rb:123").should == false
    end

    it "is not custom if it's a vendored gem" do
      AirbrakeTools.send(:custom_file?, "[PROJECT_ROOT]/vendor/bundle/xxx.rb:123").should == false
    end
  end

  describe ".present_line" do
    before do
      $stdout.stub(:tty?).and_return false
    end

    it "does not add colors" do
      AirbrakeTools.send(:present_line, "[PROJECT_ROOT]/vendor/bundle/foo.rb:123").should_not include("\e[")
      AirbrakeTools.send(:present_line, "[PROJECT_ROOT]/app/foo.rb:123").should_not include("\e[")
    end

    context "on tty" do
      before do
        $stdout.stub(:tty?).and_return true
      end

      it "shows gray for vendor lines" do
        AirbrakeTools.send(:present_line, "[PROJECT_ROOT]/vendor/bundle/foo.rb:123").should include("\e[")
      end

      it "does not add colors for project lines" do
        AirbrakeTools.send(:present_line, "[PROJECT_ROOT]/app/foo.rb:123").should_not include("\e[")
      end
    end

    it "adds blame if file exists" do
      AirbrakeTools.send(:present_line, "[PROJECT_ROOT]/Gemfile:2 adasdsad").should ==
        "Gemfile:2 adasdsad -- ^acc8204 (<jcheatham@zendesk.com> 2012-11-06 18:45:10 -0800 )"
    end

    it "does not add blame to system files" do
      AirbrakeTools.send(:present_line, "/etc/hosts:1 adasdsad").should == "/etc/hosts:1 adasdsad"
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

  describe ".project_id" do
    before do
      AirbrakeAPI.should_receive(:projects).and_return([stub(:name => "a", :id => 123), stub(:name => "b", :id => 234)])
    end

    after do
      AirbrakeTools.instance_variable_set(:@projects, nil) # unset stubs
    end

    it "returns id for a name" do
      AirbrakeTools.send(:project_id, "a").should == 123
    end

    it "raises a nice error when project was not found" do
       expect{
         AirbrakeTools.send(:project_id, "c")
       }.to raise_error(/not found/)
    end
  end
end
