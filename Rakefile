#!/usr/bin/env ruby
require 'dotenv/tasks'

task :default => [ :usage ]

task :usage do 
	
	puts <<EOF
	
This is MailAdmin, a Sinatra application to administrate Postfix.
Installation and usage instructions can be found at 
https://github.com/germania/mailadmin .

Supported rake tasks:

server:        run mailadmin using thin or WEBRick
autoresponder: WORK IN PROGRESS!  Send out autoresponder emails from goldfish 
               table, if it exists
	
EOF

end

task :server => :dotenv do
	require_relative 'lib/mailadmin.rb'
	Sinatra::Application.run!
end

task :autoresponder do
	require_relative 'lib/autoresponder.rb'
	AutoResponder::run!
end
