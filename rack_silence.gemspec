Gem::Specification.new do |s|
  s.name = 'rack_silence'
  s.version = '0.1.0'
  s.licenses = ['MIT']
  s.summary = 'Silence logs per request from Rack'
  s.description = ''
  s.authors = ['Loic Nageleisen']
  s.email = 'loic.nageleisen@gmail.com'
  s.files = Dir['lib/*']

  s.add_dependency 'rack'

  s.add_development_dependency 'rails', '>= 3.2', '< 5.0'

  s.add_development_dependency 'rake', '~> 10.3'
  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'yard', '~> 0.8.7'

  s.add_development_dependency 'pry'
end
