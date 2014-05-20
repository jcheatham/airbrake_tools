require "bundler/gem_tasks"
require "bump/tasks"

file "spec/fixtures.yml" => "spec/fixtures.example.yml" do
  cp "spec/fixtures.example.yml", "spec/fixtures.yml"
end

task :default => "spec/fixtures.yml" do
  sh "rspec spec/"
end
