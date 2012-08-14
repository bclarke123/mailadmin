#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'

require_relative 'connection'

set :show_exceptions, true
set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')
set :views, File.join(File.dirname(__FILE__), '..', 'views')

enable :sessions

before do
	@con = Connection.new
	@flash = session[:flash]
	session[:flash] = nil
end

after do
	@con.close if @con
end

before '/user/*' do
	
	unless session[:userid]
		session[:flash] = "You must log in to continue"
		r '/'
	end
	
	uid = session[:userid]
	@user = @con.get_user(uid)
	
end

before '/user/domain/:id' do |id|
	@domain = @user.admin_domains[id]
	unless @user.super_admin || @domain
		session[:flash] = "Domain #{id} not found"
		r '/user/dashboard' 
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
  def link_to url_fragment, mode=:full_url
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
    url_fragment = "/#{url_fragment}" unless url_fragment =~ /^\// 
    "#{base}#{url_fragment}"
  end
  
  def r url_fragment
  	redirect link_to url_fragment
  end
end

# Responders

get '/' do
	erb :index, :locals => { :flash => @flash }
end

post '/login' do

	email = params[:email]
	password = params[:password]

	id = session[:userid] = @con.authenticate(email, password)

	unless id
		session[:flash] = "Invalid login"
		r '/'
	end

	r '/user/dashboard'

end

get '/user' do 
	r '/user/dashboard'
end

get '/user/dashboard' do
	pass
end

get '/user/logout' do
	session[:userid] = nil
	r '/'
end

post '/user/password' do 
	
	pass = params[:password]
	conf = params[:confirmation]
	
	if pass.nil? || pass.empty?
		session[:flash] = "Password can't be blank"
	elsif pass != conf
		session[:flash] = "Password and confirmation don't match"
=begin
TODO better password strength algo
=end
	else
		@con.update_password(session[:userid], pass)
		session[:flash] = "Password updated"
	end
	
	r '/user/dashboard'
end

post '/user/domain/new' do
	
	name = params[:name]
	
	unless @user.super_admin
		r "/user/dashboard"
	end
	
	if name.nil? or name.empty?
		session[:flash] = "No name specified"
		r "/user/dashboard"
	end
	
	@con.add_domain(name, @user.id)
	session[:flash] = "Domain #{name} added"
	r '/user/dashboard'

end

post '/user/domain/:id/delete' do |id|
	
	if @user.super_admin
		
		@con.delete_domain(id)
		
	end
	
	r '/user/dashboard'
	
end

get '/user/domain/:id' do |id|
	
	erb :user_domain, 
		:locals => { 
			:flash => @flash, 
			:user => @user, 
			:domain => @domain,
			:users => @con.domain_users(@domain),
			:aliases => @con.domain_aliases(@domain)
		}
		
end

get '/user/email/:id' do |id|
	
	user = @con.get_user(id)
	did = user.domain_id
	
	domain = @user.admin_domains[did]
	unless domain
		session[:flash] = "User #{id} not found"
		r '/user/dashboard' 
	end
	
	erb :edit_user,
		:locals => {
			:flash => @flash,
			:user => @user,
			:subject => user
		}
	
end

post '/user/email/new' do
	
	lh = params[:lh]
	pass = params[:pass]
	conf = params[:conf]
	id = params[:domain]
	super_admin = params[:super_admin] == "1"
	
	domain = @user.admin_domains[id]
	unless domain
		session[:flash] = "Domain #{id} not found"
		r '/user/dashboard' 
	end
	
	admin_domains = []
	@user.admin_domains.each do |did, d|
		admin_domains << did if params["admin_#{did}".intern] == "1"
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
	elsif @con.login_exists?(lh, domain)
		flash = "Address #{lh} already exists for domain #{domain.name}"
	end
	
	if flash
		session[:flash] = flash
	else
		@con.add_user(lh, domain, pass, admin_domains, super_admin)
		session[:flash] = "User #{lh}@#{domain.name} added."
	end
	
	r '/user/dashboard'
	
end

post '/user/email/:id' do |id|
	
	pass = params[:pass]
	conf = params[:conf]
	sa = params[:super_admin]
	
	user = @con.get_user(id)
	
	if user.nil?
		session[:flash] = "User #{id} not found"
		r '/user/dashboard'
	end
	
	# only have to validate password and admin settings
	unless pass.nil? or pass.empty?
		if pass != conf
			session[:flash] = "Password and confirmation don't match"
			r "/user/email/#{id}"
		end
	end
	
	admin_domains = []
	@user.admin_domains.each do |did, d|
		admin_domains << did if params["admin_#{did}".intern] == "1"
	end
	
	@con.update_user(id, pass, admin_domains, sa)
	
	session[:flash] = "User #{user.email} updated."
	r "/user/email/#{id}"
	
end

post '/user/email/:id/delete' do |uid|
	
	user = @con.get_user(uid)
	
	if user.nil?
		session[:flash] = "User not found"
		r '/user/dashboard'
	end
	
	unless @user.admin_domains.has_key?(user.domain_id)
		session[:flash] = "User not found"
		r '/user/dashboard'
	end
	
	@con.delete_user(uid)
	
	session[:flash] = "User #{user.email} deleted."
	r "/user/domain/#{user.domain_id}"
	
end

post '/user/alias/new' do
	
	slh = params[:slh]
	dlh = params[:dlh]
	src_id = params[:src_domain]
	dst_id = params[:dst_domain]
	src = @user.admin_domains[src_id]
	dst = @user.admin_domains[dst_id]
	
	if src_id.nil? || src.nil?
		session[:flash] = "Invalid source domain"
		r '/user/dashboard'
	end
	
	if dst_id.nil? || dst.nil?
		session[:flash] = "Invalid destination domain"
		r '/user/dashboard'
	end
	
	if dlh.nil? || dlh.empty?
		session[:flash] = "Destination user can't be blank"
		r '/user/dashboard'
	end
	
	src_email = "#{slh}@#{src.name}"
	dst_email = "#{dlh}@#{dst.name}"
	
	e_src = @con.get_alias_by_name(src_email, :src)
	
	unless e_src.nil?
		session[:flash] = "Source address #{src_email} already exists"
		r '/user/dashboard'
	end
	
	@con.add_alias(src, src_email, dst_email)
	session[:flash] = "Added alias #{src_email} &rarr; #{dst_email}"
	r '/user/dashboard'
	
end

post '/user/alias/:aid/delete' do |aid|
	
	a = @con.get_alias(aid)
	
	if a.nil?
		session[:flash] = "Alias not found"
		r '/user/dashboard'
	end
	
	unless @user.admin_domains.has_key?(a.domain_id)
		session[:flash] = "Alias not found"
		r '/user/dashboard'
	end
	
	@con.delete_alias(aid)
	
	session[:flash] = "Alias #{a.source} &rarr; #{a.destination} deleted."
	r "/user/domain/#{a.domain_id}"
	
end

get '/user/:cmd' do |cmd|
	user_cmd = "user_#{cmd}".intern
	erb user_cmd, :locals => { :flash => @flash, :user => @user }
end

