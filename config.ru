require './run'

set :environment, ENV['RACK_ENV'].to_sym

# this line is needed if you run this app behind a transparent proxy
# set :protection, :except => [:http_origin]

set :app_file, 'run.rb'
disable :run

log = File.new("logs/mailadmin.log", "a")
#STDOUT.reopen(log) # Redirecting STDOUT kills passanger! https://github.com/phusion/passenger/wiki/Debugging-application-startup-problems 
STDERR.reopen(log)

run Sinatra::Application

