#!/usr/bin/env ruby

require 'mysql'
require 'digest/md5'

require_relative 'config'
require_relative 'classes'

class Connection
	def initialize
		@con = Mysql::real_connect(
			MailConfig::DB_HOST, 
			MailConfig::DB_USER, 
			MailConfig::DB_PASS, 
			MailConfig::DB_DB
		)
	end
	
	def close
		@con.close if @con
	end
	
	def authenticate(email, password)
		
		if email.nil? || email.empty? || password.nil? || password.empty?
			return false
		end
		
		q = @con.query(
			"select id, password from " + MailConfig::TABLE_USERS + " where email = '%s';" % 
				@con.escape_string(email))
		
		id, hash = q.fetch_row
		
		return false unless id
		
		if Digest::MD5.hexdigest(password) == hash
			return id
		end
		
		return false
		
	end
	
	def login_exists?(lh, domain)
		
		q = @con.query("select count(*) from " + MailConfig::TABLE_USERS + " where email = '%s'" %
			@con.escape_string("#{lh}@#{domain.name}") )
		
		return q.fetch_row.first.to_i > 0
		
	end
	
	def update_password(id, password)
		
		@con.query("update " + MailConfig::TABLE_USERS + " set password = '%s' where id = %d;" %
			[ Digest::MD5.hexdigest(password), id ])
		
	end
	
	def get_user(id)
		
		q = @con.query(
			"select " + MailConfig::TABLE_USERS + ".*, " + MailConfig::TABLE_DOMAINS + ".id as admin_domain_id, 
			" + MailConfig::TABLE_DOMAINS + ".name as admin_domain_name 
			from " + MailConfig::TABLE_USERS + " 
			left join " + MailConfig::TABLE_ADMINS + " on " + MailConfig::TABLE_USERS + ".id = " + MailConfig::TABLE_ADMINS + ".user_id
			left join " + MailConfig::TABLE_DOMAINS + " on " + MailConfig::TABLE_ADMINS + ".domain_id = " + MailConfig::TABLE_DOMAINS + ".id 
			or " + MailConfig::TABLE_USERS + ".super_admin
			where " + MailConfig::TABLE_USERS + ".id = %d order by admin_domain_name desc;" % id)
		
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
		
# we do this this way so we don't depend on having goldfish installed
		if test_goldfish
			
			ar = user.autoresponder = AutoResponder.new
			
			q = @con.query("select * from autoresponder where email = '%s'" %
				user.email)
			row = q.fetch_hash
			if row
				
				ar.email = row['email']
				ar.descname = row['descname']
				ar.from = Date.strptime(row['from'], '%Y-%m-%d')
				ar.to = Date.strptime(row['to'], '%Y-%m-%d')
				ar.message = row['message']
				ar.enabled = row['enabled'].to_i == 1
				ar.subject = row['subject']
				
			end
		end
		
		return user
		
	end
	
	def add_user(lh, domain, password, admin_domains, super_admin)
		
		email = @con.escape_string("#{lh}@#{domain.name}")
		
		@con.query("insert into %s set domain_id = %d, password = '%s', email = '%s', super_admin = %d " %
			[ MailConfig::TABLE_USERS, domain.id, Digest::MD5.hexdigest(password), email, super_admin ? 1 : 0 ])
		
		if admin_domains && admin_domains.length > 0
			id = insert_id
			
			admin_domains.each do |did|
				@con.query("insert into " + MailConfig::TABLE_ADMINS + " values(%d, %d)" % [ did, id ])
			end
		end
		
		@con.query("insert into " + MailConfig::TABLE_ALIASES + " values(NULL, %d, '%s', '%s')" %
			[ domain.id, email, email ])
		
	end
	
	def update_user(uid, password, admin_domains, super_admin)
		
		if password.nil? or password.empty?
			password = "password"
		else
			password = "'%s'" % Digest::MD5.hexdigest(password)
		end
		
		sa = super_admin ? 1 : 0
		
		@con.query("update " + MailConfig::TABLE_USERS + " set password = %s, super_admin = %d 
			where id = %d;" % [ password, sa, uid ])
		
=begin
TODO by deleting all the existing admin info, we disallow 2 admins with
access to 2 different domains the ability to give the same user access
to domains the other can't see -- it'll delete ones that "I" can't check.
=end

		@con.query("delete from " + MailConfig::TABLE_ADMINS + " where user_id = %d;" % uid)
		
		sql = nil
		admin_domains.each do |did|
			(sql ||= "insert into " + MailConfig::TABLE_ADMINS + " values") << " (#{did}, #{uid})," 
		end
		
		@con.query(sql.gsub(/,$/, '')) unless sql.nil?
		
	end
	
	def delete_user(uid)
		
		user = get_user(uid)
		
		if test_goldfish
			@con.query("delete from autoresponder where email = '%s'" % 
				@con.escape_string(user.email))
		end
		
		@con.query("delete from " + MailConfig::TABLE_ADMINS + " where user_id = %d" % uid)
		@con.query("delete from " + MailConfig::TABLE_ALIASES + " where destination = '%s'" % 
			@con.escape_string(user.email))
		@con.query("delete from " + MailConfig::TABLE_USERS + " where id = %d" % uid)
		
	end
	
	def domain_users(domain)
		
		q = @con.query("select " + MailConfig::TABLE_USERS + ".*, " + MailConfig::TABLE_ADMINS + ".domain_id as is_admin 
			from " + MailConfig::TABLE_USERS + " left join " + MailConfig::TABLE_ADMINS + " 
			on " + MailConfig::TABLE_USERS + ".domain_id = " + MailConfig::TABLE_ADMINS + ".domain_id
			and " + MailConfig::TABLE_ADMINS + ".user_id = " + MailConfig::TABLE_USERS + ".id
			where " + MailConfig::TABLE_USERS + ".domain_id = %d order by email asc" % domain.id)
		
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
		
		q = @con.query("select * from " + MailConfig::TABLE_ALIASES + "
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
		
		@con.query("insert into " + MailConfig::TABLE_DOMAINS + " values(NULL, '%s');" % 
			@con.escape_string(name))
		
		id = insert_id
		
		@con.query("insert into " + MailConfig::TABLE_ADMINS + " values(%d, %d);" % [ id, uid ])
		
	end
	
	def delete_domain(id)
		
		@con.query("delete from " + MailConfig::TABLE_USERS + " where domain_id = %d;" % id)
		@con.query("delete from " + MailConfig::TABLE_ALIASES + " where domain_id = %d;" % id)
		@con.query("delete from " + MailConfig::TABLE_ADMINS + " where domain_id = %d;" % id)
		@con.query("delete from " + MailConfig::TABLE_DOMAINS + " where id = %d;" % id)
		
	end
	
	def get_alias(aid)
		
		q = @con.query("select * from " + MailConfig::TABLE_ALIASES + " where id = %d" % aid)
		
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
		
		q = @con.query("select id from " + MailConfig::TABLE_ALIASES + " where %s = '%s'" % 
			[ f, @con.escape_string(name) ])
		
		return row[0] if row = q.fetch_row
		
		return nil
		
	end
	
	def add_alias(src_domain, src, dst)
		
		@con.query("insert into " + MailConfig::TABLE_ALIASES + " values (NULL, %d, '%s', '%s')" %
			[ src_domain.id, @con.escape_string(src), @con.escape_string(dst) ])
		
	end
	
	def delete_alias(aid)
		@con.query("delete from " + MailConfig::TABLE_ALIASES + " where id = %d" % aid)
	end

	def insert_id
		@con.query("select last_insert_id()").fetch_row.first
	end
	
	def test_goldfish
		begin
			@con.query("select email from autoresponder limit 1");
			return true
		rescue
			return false
		end
	end
	
	def save_autoresponder(email, descname, from, to, message, enabled, subject)
		
		return false unless test_goldfish
		
		from_str = from.strftime('%Y-%m-%d')
		to_str = to.strftime('%Y-%m-%d')
		
		@con.query("replace into autoresponder values('%s', '%s', '%s', '%s', '%s', %d, '%s')" %
			[ 
				@con.escape_string(email),
				@con.escape_string(descname),
				@con.escape_string(from_str),
				@con.escape_string(to_str),
				@con.escape_string(message),
				enabled ? 1 : 0,
				@con.escape_string(subject)
			]
		)
		
	end
	
	def each_autoresponder
		
		return unless test_goldfish
		
		q = @con.query("select * from `autoresponder` where `enabled` 
			and `from` <= NOW() and `to` > NOW()")
		
		while row = q.fetch_hash
			yield row
		end
		
	end
	
	def already_responded?(user, recipient)
		
		return false unless test_goldfish
		
		q = @con.query("select 1 from autoresponder_recipients 
			left join autoresponder 
			on autoresponder_recipients.user_email = autoresponder.email 
			where autoresponder.email = '%s' 
			and autoresponder_recipients.recipient_email = '%s' 
			and autoresponder_recipients.send_date >= autoresponder.`from`" %
				[ @con.escape_string(user), @con.escape_string(recipient) ])
		
		if q.fetch_row
			return true
		end
		
		return false
		
	end
	
	def mark_responded(user, recipient)
		
		return false unless test_goldfish
		
		@con.query("replace into autoresponder_recipients values('%s', '%s', now())" %
			[ @con.escape_string(user), @con.escape_string(recipient) ])
		
	end
	
end
