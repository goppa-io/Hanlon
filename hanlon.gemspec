# Bundler Gemspec only supports one explicit ruby version
raise 'Ruby should be ~>2.2' unless RUBY_VERSION.to_f >= 2.2

Gem::Specification.new do |s|
  s.name        = 'project_hanlon'
  s.version     = '3.0.1'
  s.licenses    = 'Apache-2.0'
  s.date        = '2015-11-15'
  s.summary     = 'Project Hanlon'
  s.description = 'Next-generation automation software for bare-metal and virtual server provisioning'
  s.authors     = ['Nicholas Weaver', 'Tom McSweeney']
  s.email       = ['lynxbat@gmail.com','tjmcs@bendbroadband.com']
  s.files       = ['core/hanlon_global.rb']
  s.homepage    = 'https://github.com/csc/Hanlon/blob/master/README.md'

  s.add_runtime_dependency('base62', '~> 1.0')
  s.add_runtime_dependency('bzip2-ffi', '~> 1.0')
  s.add_runtime_dependency('cassandra-driver', '~> 2.1')
  s.add_runtime_dependency('colored', '~> 1.2')
  s.add_runtime_dependency('daemons', '~> 1.2')
  s.add_runtime_dependency('facter', '~> 2.4')
  s.add_runtime_dependency('grape', '~> 0.13.0')          # No 1.0 release available (Dec 2015)
  s.add_runtime_dependency('grape-swagger', '~> 0.10.2')  # No 1.0 release available (Dec 2015)
  s.add_runtime_dependency('json', '~> 1.8')
  s.add_runtime_dependency('logger', '~> 1.2')
  s.add_runtime_dependency('mongo', '~> 1.12')            # hanlon hasn't been tested with mongo 2.0
  s.add_runtime_dependency('net-scp', '~> 1.2')
  s.add_runtime_dependency('net-ssh', '~> 3.0')
  s.add_runtime_dependency('pg', '~> 0.18.4')             # No 1.0 release available (Dec 2015)
  s.add_runtime_dependency('puma', '~> 3.7.0')
  s.add_runtime_dependency('pry', '~> 0.10.4')
  s.add_runtime_dependency('pry-byebug', '~> 3.5.0')
  s.add_runtime_dependency('rubyipmi', '~> 0.10.0')       # No 1.0 release available (Dec 2015)
  s.add_runtime_dependency('rufus-scheduler', '~> 3.1')
  s.add_runtime_dependency('uuid', '~> 2.3')

  s.add_development_dependency('rspec', '~> 3.4')
  s.add_development_dependency('rspec-expectations', '~> 3.4')
  s.add_development_dependency('rspec-mocks', '~> 3.4')
end
