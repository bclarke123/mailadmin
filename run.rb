#!/usr/bin/env ruby
require 'rubygems'

require 'dotenv'
Dotenv.load

require 'bundler'

Bundler.require(:default, ENV['RACK_ENV'].to_sym)


require 'sinatra'
require_relative 'lib/mailadmin.rb'
