#!/usr/bin/env ruby
require 'rubygems'

require 'dotenv'
Dotenv.load

require 'bundler'

Bundler.require(:default, :development)



require 'sinatra'
require_relative 'lib/mailadmin.rb'
