ROOT = File.expand_path('../../', __FILE__)

describe "airbrake-tools" do
  def run(command, options={})
    result = `#{command} 2>&1`
    message = (options[:fail] ? "SUCCESS BUT SHOULD FAIL" : "FAIL")
    raise "[#{message}] #{result} [#{command}]" if $?.success? == !!options[:fail]
    result
  end

  def airbrake_tools(args, options={})
    run "#{ROOT}/bin/airbrake-tools #{args}", options
  end

  before do
    Dir.chdir ROOT
  end

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

end
