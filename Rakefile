require "rake/testtask"

task :default => [:test]

Rake::TestTask.new do |test|
  test.libs       << "test"
  test.test_files =  %w[test/ts_all.rb]
  test.verbose    =  true
end
