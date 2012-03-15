source 'http://rubygems.org'

gem 'rails', '3.2.2' 
gem 'devise'
gem 'default_value_for'
gem 'jquery-rails'
gem 'will_paginate'
gem 'simple_form'
gem 'pg'
gem 'cancan'
gem 'userstamp', git: "git://github.com/keviniano/userstamp.git"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', "  ~> 3.2.3"
  gem 'coffee-rails', "~> 3.2.1"
  gem 'uglifier', '>= 1.0.3'
end

group :development, :test do 
  if RUBY_VERSION =~ /1.9/ 
    gem 'ruby-debug19' 
  else 
    gem 'ruby-debug' 
  end 
  gem "nifty-generators"
end

