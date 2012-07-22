#!/usr/bin/env ruby

require 'mysql'
require 'digest/md5'

require 'config'

class MailHelper
	def initialize
		@con = Mysql::real_connect(
			Config::DB_HOST, Config::DB_USER, Config::DB_PASS, Config::DB_DB)
	end
	
	def close
		@con.close if @con
	end
	
	def authenticate(email, password)
		
		if email.nil? || email.empty? || password.nil? || password.empty?
			return false
		end
		
		q = @con.query(
			"select id, password from virtual_users where email = '%s';" % 
				@con.escape_string(email))
		
		id, hash = q.fetch_row
		
		return false unless id
		
		if Digest::MD5.hexdigest(password) == hash
			return id
		end
		
		return false
		
	end
	
	def get_user(id)
		
		q = @con.query("select * from virtual_users where id = %d;" % id)
		return q.fetch_hash
		
	end
	
	def update_password(id, password)
		
		@con.query("update virtual_users set password = '%s' where id = %d;" %
			[ Digest::MD5.hexdigest(password), id ])
		
	end
	
end
