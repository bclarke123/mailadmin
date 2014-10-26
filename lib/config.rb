#!/usr/bin/env ruby

module MailConfig
	DB_HOST = "localhost"
	DB_USER = ENV['DB_USER']
	DB_PASS = ENV['DB_PASS']
	DB_DB = "mailserver"
	
	TABLE_ADMINS  = "domain_admins"
	TABLE_USERS   = "virtual_users"
	TABLE_DOMAINS = "virtual_domains"
	TABLE_ALIASES = "virtual_aliases"
  
	HTTP_SCHEME = 'http'
	HTTP_HOST   = 'localhost'
	HTTP_PORT   = 9393

	PASS_SCHEME  = 'SSHA512'
	SALT_LENGTH = 8
	
# If you're going to use the built-in autoresponder, this should return a
# user's maildir mailbox when %u is replaced with their username, and %d with
# the domain
	AR_MAILDIR = "/var/mail/vhosts/%d/%u"
	AR_SERVER = "localhost"
	
end
