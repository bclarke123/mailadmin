#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require 'config'
require 'mailhelper'

enable :sessions

before do
	@helper = MailHelper.new
	@flash = session[:flash]
	session[:flash] = nil
end

after do
	@helper.close if @helper
end

before '/user/*' do
	
	unless session[:userid]
		session[:flash] = "You must log in to continue"
		redirect '/'
	end
	
	uid = session[:userid]
	@user = @helper.get_user(uid)
	
end

# Responders

get '/' do
	erb :index, :locals => { :flash => @flash }
end

post '/login' do

	email = params[:email]
	password = params[:password]

	id = session[:userid] = @helper.authenticate(email, password)

	unless id
		session[:flash] = "Invalid login"
		redirect '/'
	end

	redirect '/user/dashboard'

end

get '/user' do 
	redirect '/user/dashboard'
end

get '/user/dashboard' do
	pass
end

get '/user/logout' do
	session[:userid] = nil
	redirect '/'
end

get '/user/:cmd' do |cmd|
	user_cmd = "user_#{cmd}".intern
	erb user_cmd, :locals => { :flash => @flash, :user => @user }
end

post '/user/password' do 
	
	pass = params[:password]
	conf = params[:confirmation]
	
	if pass.nil? || pass.empty?
		session[:flash] = "Password can't be blank"
	elsif pass != conf
		session[:flash] = "Password and confirmation don't match"
	else
		session[:flash] = "Password updated"
		@helper.update_password(session[:userid], pass)
	end
	
	redirect '/user/dashboard'
end

