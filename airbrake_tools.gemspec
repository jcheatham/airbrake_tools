$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "airbrake_tools"
require "#{name}/version"

Gem::Specification.new name, AirbrakeTools::VERSION do |s|
  s.summary = "Power tools for Airbrake"
  s.authors = ["Jonathan Cheatham"]
  s.email = "coaxis@gmail.com"
  s.homepage = "http://github.com/jcheatham/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  s.executables = ["airbrake-tools"]
  s.add_runtime_dependency "airbrake-api", ">= 4.5.1"
end
