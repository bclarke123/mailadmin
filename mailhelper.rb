#!/usr/bin/env ruby

require 'mysql'
require 'digest/md5'

require 'alias'
require 'config'
require 'domain'
require 'user'

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
	
	def login_exists?(lh, domain)
		
		q = @con.query("select count(*) from virtual_users where email = '%s'" %
			@con.escape_string("#{lh}@#{domain.name}") )
		
		return q.fetch_row.first.to_i > 0
		
	end
	
	def update_password(id, password)
		
		@con.query("update virtual_users set password = '%s' where id = %d;" %
			[ Digest::MD5.hexdigest(password), id ])
		
	end
	
	def get_user(id)
		
		q = @con.query(
			"select virtual_users.*, virtual_domains.id as admin_domain_id, 
			virtual_domains.name as admin_domain_name 
			from virtual_users 
			left join domain_admins on virtual_users.id = domain_admins.user_id
			left join virtual_domains on domain_admins.domain_id = virtual_domains.id 
			or virtual_users.super_admin
			where virtual_users.id = %d order by admin_domain_name desc;" % id)
		
		user = nil
		
		while row = q.fetch_hash
			
			if user.nil?
				user = User.new
				user.id = row['id']
				user.email = row['email']
				user.password = row['password']
				user.domain_id = row['domain_id']
				user.super_admin = row['super_admin'] == "1"
				user.admin_domains = {}
			end
			
			if row['admin_domain_id']
				domain = Domain.new
				domain.id = row['admin_domain_id']
				domain.name = row['admin_domain_name']
				user.admin_domains[domain.id] = domain
			end
			
		end
		
		return user
		
	end
	
	def add_user(lh, domain, password, admin_domains, super_admin)
		
		email = @con.escape_string("#{lh}@#{domain.name}")
		
		@con.query("insert into virtual_users values(NULL, %d, '%s', '%s', %d)" %
			[ domain.id, Digest::MD5.hexdigest(password), email, super_admin ? 1 : 0 ])
		
		if admin_domains && admin_domains.length > 0
			q = @con.query("select last_insert_id()")
			id = q.fetch_row.first
			
			admin_domains.each do |did|
				@con.query("insert into domain_admins values(%d, %d)" % [ did, id ])
			end
		end
		
		@con.query("insert into virtual_aliases values(NULL, %d, '%s', '%s')" %
			[ domain.id, email, email ])
		
	end
	
	def update_user(uid, password, admin_domains, super_admin)
		
		if password.nil? or password.empty?
			password = "password"
		else
			password = "'%s'" % Digest::MD5.hexdigest(password)
		end
		
		sa = super_admin ? 1 : 0
		
		@con.query("update virtual_users set password = %s, super_admin = %d 
			where id = %d;" % [ password, sa, uid ])
		
=begin
TODO by deleting all the existing admin info, we disallow 2 admins with
access to 2 different domains the ability to give the same user access
to domains the other can't see -- it'll delete ones that "I" can't check.
=end

		@con.query("delete from domain_admins where user_id = %d;" % uid)
		
		sql = nil
		admin_domains.each do |did|
			(sql ||= "insert into domain_admins values") << " (#{did}, #{uid})," 
		end
		
		@con.query(sql.gsub(/,$/, '')) unless sql.nil?
		
	end
	
	def delete_user(uid)
		
		user = get_user(uid)
		
		@con.query("delete from domain_admins where user_id = %d" % uid)
		@con.query("delete from virtual_aliases where destination = '%s'" % 
			@con.escape_string(user.email))
		@con.query("delete from virtual_users where id = %d" % uid)
		
	end
	
	def domain_users(domain)
		
		q = @con.query("select virtual_users.*, domain_admins.domain_id as is_admin 
			from virtual_users left join domain_admins 
			on virtual_users.domain_id = domain_admins.domain_id
			and domain_admins.user_id = virtual_users.id
			where virtual_users.domain_id = %d order by email asc" % domain.id)
		
		ret = []
		
		while row = q.fetch_hash
			
			user = User.new
			user.id = row['id']
			user.email = row['email']
			user.admin_domains = [ row['is_admin'] ]
			
			ret << user
			
		end
				
		return ret
		
	end
	
	def domain_aliases(domain)
		
		q = @con.query("select * from virtual_aliases
			where domain_id = %d and source != destination order by source asc" % domain.id)
		ret = []
		while row = q.fetch_hash
			
			a = Alias.new
			a.id = row['id']
			a.source = row['source']
			a.destination = row['destination']
			
			ret << a
			
		end
		
		return ret
		
	end
	
	def add_domain(name, uid)
		
		@con.query("insert into virtual_domains values(NULL, '%s');" % 
			@con.escape_string(name))
		
		id = @con.query("select last_insert_id();").fetch_row.first
		
		@con.query("insert into domain_admins values(%d, %d);" % [ id, uid ])
		
	end
	
	def delete_domain(id)
		
		@con.query("delete from virtual_users where domain_id = %d;" % id)
		@con.query("delete from virtual_aliases where domain_id = %d;" % id)
		@con.query("delete from domain_admins where domain_id = %d;" % id)
		@con.query("delete from virtual_domains where id = %d;" % id)
		
	end
	
	def get_alias(aid)
		
		q = @con.query("select * from virtual_aliases where id = %d" % aid)
		
		ret = nil
		
		if row = q.fetch_hash
			
			ret = Alias.new
			ret.id = row['id']
			ret.source = row['source']
			ret.destination = row['destination']
			ret.domain_id = row['domain_id']
			
		end
		
		return ret
		
	end
	
	def get_alias_by_name(name, field = :src)
		
		f = field == :src ? "source" : "destination"
		
		q = @con.query("select id from virtual_aliases where %s = '%s'" % 
			[ f, @con.escape_string(name) ])
		
		return row[0] if row = q.fetch_row
		
		return nil
		
	end
	
	def add_alias(src_domain, src, dst)
		
		@con.query("insert into virtual_aliases values (NULL, %d, '%s', '%s')" %
			[ src_domain.id, @con.escape_string(src), @con.escape_string(dst) ])
		
	end
	
	def delete_alias(aid)
		@con.query("delete from virtual_aliases where id = %d" % aid)
	end
	
end
