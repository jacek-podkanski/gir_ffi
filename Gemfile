source "https://rubygems.org"

# The gem's dependencies are specified in gir_ffi.gemspec
gemspec

if ENV["CI"]
  if RUBY_ENGINE == "ruby"
    gem 'coveralls', require: false
  end
else
  gem 'pry'
  gem 'repl_rake'
  gem 'ZenTest'
  gem 'autotest-suffix'
  gem 'yard'

  if RUBY_ENGINE == 'ruby'
    gem 'simplecov', require: false
  end
end

gem 'rubysl', :platform => :rbx
