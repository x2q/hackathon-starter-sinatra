source 'https://rubygems.org'

gem 'activerecord'
gem 'activesupport', require: ['active_support', 'active_support/core_ext']
gem 'bcrypt'
gem 'bcrypt-ruby' #legacy
gem 'dotenv'
gem 'haml'
gem 'json'
gem 'mail'
gem 'nokogiri' #premailer wants this
gem 'premailer' #for inlining email styles
gem 'rack-flash3', require: 'rack-flash'
gem 'rake'
gem 'redcarpet', require: 'redcarpet/compat' #markdown rendering
gem 'require_all'
gem 'sinatra'
gem 'sinatra-activerecord', require: 'sinatra/activerecord'
gem 'sinatra-assetpack', :require => 'sinatra/assetpack'
gem 'sinatra-contrib', require: 'sinatra/config_file'
gem 'sinatra-flash', require: 'sinatra/flash'
gem 'squeel'
gem 'stripe'
gem 'tux'
gem 'therubyracer'
gem 'less'

group :development do
    gem "sqlite3"
    gem "shotgun"
end

group :production do 
    gem "pg"                        # Needed for postgresql on Heroku
end
