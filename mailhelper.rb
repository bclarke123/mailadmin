#!/usr/bin/env ruby

require 'mysql'
require 'digest/md5'

require 'config'
require 'user'
require 'domain'

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
		
		q = @con.query(
			"select virtual_users.*, virtual_domains.id as admin_domain_id, 
			virtual_domains.name as admin_domain_name 
			from virtual_users 
			left join domain_admins on virtual_users.id = domain_admins.user_id 
			left join virtual_domains on domain_admins.domain_id = virtual_domains.id 
			where virtual_users.id = %d order by admin_domain_name desc;" % id)
		
		user = User.new
		first = true
		
		while row = q.fetch_hash
			
			if first
				user.id = row['id']
				user.email = row['email']
				user.password = row['password']
				user.domain_id = row['domain_id']
			end
			
			if row['admin_domain_id']
				domain = Domain.new
				domain.id = row['admin_domain_id']
				domain.name = row['admin_domain_name']
				(user.admin_domains ||= {})[domain.id] = domain
			end
			
			first = false
			
		end
		
		return user
		
	end
	
	def update_password(id, password)
		
		@con.query("update virtual_users set password = '%s' where id = %d;" %
			[ Digest::MD5.hexdigest(password), id ])
		
	end
	
	def add_user(lh, domain, password, admin)
		
		@con.query("insert into virtual_users values(NULL, %d, '%s', '%s')" %
			[ domain.id, Digest::MD5.hexdigest(password), "#{lh}@#{domain.name}" ])
		
	end
	
	def login_exists?(lh, domain)
		
		q = @con.query("select count(*) from virtual_users where email = '%s'" %
			@con.escape_string("#{lh}@#{domain.name}") )
		
		return q.fetch_row.first.to_i > 0
		
	end
	
end
