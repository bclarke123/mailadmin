#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

pwd = Dir.pwd
Daemons.run_proc('mailadmin.rb', 
	{:dir_mode => :normal, 
		:dir => File.dirname(__FILE__)}) do
	Dir.chdir(pwd)
	exec "ruby lib/mailadmin.rb"
end
