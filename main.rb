#!/usr/bin/env ruby

require 'rubygems'
require 'daemons'

pwd = Dir.pwd
Daemons.run_proc('mailadmin.rb', 
	{:dir_mode => :normal, :dir => "/home/jamin/mailadmin"}) do
	Dir.chdir(pwd)
	exec "ruby mailadmin.rb"
end
