require './run'

set :environment, ENV['RACK_ENV'].to_sym
set :app_file, 'run.rb'
disable :run

log = File.new("logs/mailadmin.log", "a")
STDOUT.reopen(log)
STDERR.reopen(log)

run Sinatra::Application
