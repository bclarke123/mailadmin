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

before '/user/domain/:id' do |id|
	@domain = @user.admin_domains[id]
	unless @domain
		session[:flash] = "Domain #{id} not found"
		redirect '/user/dashboard' 
	end
end

helpers do
  # Construct a link to +url_fragment+, which should be given relative to
  # the base of this Sinatra app.  The mode should be either
  # <code>:path_only</code>, which will generate an absolute path within
  # the current domain (the default), or <code>:full_url</code>, which will
  # include the site name and port number.  The latter is typically necessary
  # for links in RSS feeds.  Example usage:
  #
  #   link_to "/foo" # Returns "http://example.com/myapp/foo"
  #
  #--
  # Thanks to cypher23 on #mephisto and the folks on #rack for pointing me
  # in the right direction.
  # taken from https://gist.github.com/98310
  def link_to url_fragment, mode=:path_only
    case mode
    when :path_only
      base = request.script_name
    when :full_url
      if (request.scheme == 'http' && request.port == 80 ||
          request.scheme == 'https' && request.port == 443)
        port = ""
      else
        port = ":#{request.port}"
      end
      base = "#{request.scheme}://#{request.host}#{port}#{request.script_name}"
    else
      raise "Unknown script_url mode #{mode}"
    end
    "#{base}#{url_fragment}"
  end
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

get '/user/domain/:id' do |id|
	
	erb :user_domain, 
		:locals => { 
			:flash => @flash, 
			:user => @user, 
			:domain => @domain,
			:users => @helper.domain_users(@domain),
			:aliases => @helper.domain_aliases(@domain)
		}
		
end

post '/user/domain/:id/new' do |id|
	
	lh = params[:lh]
	pass = params[:pass]
	conf = params[:conf]
	admin = "1" == params[:admin]
	
# TODO this should be in a before but it don't work as-is 
	domain = @user.admin_domains[id]
	unless domain
		session[:flash] = "Domain #{id} not found"
		redirect '/user/dashboard' 
	end
	
	flash = nil
	if lh.nil? or lh.empty?
		flash = "Address can't be empty"
	elsif lh =~ /[^a-z0-9\.\-_]/i
		flash = "Invalid character(s) in address"
	elsif pass.nil? or pass.empty?
		flash = "Password can't be blank"
	elsif pass != conf
		flash = "Password and confirmation don't match"
	elsif @helper.login_exists?(lh, domain)
		flash = "Address #{lh} already exists for domain #{domain.name}"
	end
	
	if flash
		session[:flash] = flash
	else
		@helper.add_user(lh, domain, pass, admin)
		session[:flash] = "User #{lh}@#{domain.name} added."
	end
	
	redirect "/user/domain/#{id}"
	
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
		@helper.update_password(session[:userid], pass)
		session[:flash] = "Password updated"
	end
	
	redirect '/user/dashboard'
end

post '/user/email/:id/delete' do |uid|
	
	user = @helper.get_user(uid)
	
	if user.nil?
		session[:flash] = "User not found"
		redirect '/user/dashboard'
	end
	
	unless @user.admin_domains.has_key?(user.domain_id)
		session[:flash] = "User not found"
		redirect '/user/dashboard'
	end
	
	@helper.delete_user(uid)
	
	session[:flash] = "User #{user.email} deleted."
	redirect "/user/domain/#{user.domain_id}"
	
end

post '/user/alias/:aid/delete' do |aid|
	
	a = @helper.get_alias(aid)
	
	if a.nil?
		session[:flash] = "Alias not found"
		redirect '/user/dashboard'
	end
	
	unless @user.admin_domains.has_key?(a.domain_id)
		session[:flash] = "Alias not found"
		redirect '/user/dashboard'
	end
	
	@helper.delete_alias(aid)
	
	session[:flash] = "Alias #{a.source} &rarr; #{a.destination} deleted."
	redirect "/user/domain/#{a.domain_id}"
	
end


