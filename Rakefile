require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task :setup do
  `bundle exec rake appraisal install`.split(/\n/).map {|line| puts line}
end

task :default => :test
