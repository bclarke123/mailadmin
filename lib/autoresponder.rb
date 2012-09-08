#!/usr/bin/env ruby

require_relative 'connection'
require 'maildir'
require 'net/smtp'

class AutoResponder

	def initialize
		@con = Connection.new
	end
	
	def close
		@con.close if @con
	end
	
	def respond
		
		dir = MailConfig::AR_MAILDIR
		
		@con.each_autoresponder do |x|
			
			email = x['email']
			descname = x['descname']
			from = Date.strptime(x['from'], '%Y-%m-%d')
			to = Date.strptime(x['to'], '%Y-%m-%d')
			subject = x['subject']
			body = x['message']
			
			/^(?<user>.+)\@(?<domain>[^\@]+)$/ =~ email
			my_dir = dir.gsub(/%./, { '%u' => user, '%d' => domain })
			
			maildir = Maildir.new(my_dir, false)
			
# first process anything in new/ since it's a stupid way to determine
# whether we've sent a response
			maildir.list(:new).each {|m| m.process }
			
			maildir.list(:cur, :flags => '').each do |message| 
				
				next unless message.flags.empty?
				
				data = message.data
				sender = header("From", data)
				reply_to = header("Reply-To", data)
				precedence = header("Precedence", data)
				list_unsub = header("List-Unsubscribe", data)
				spam = header("X-Spam-Flag", data)
				
				reply_to = sender if reply_to.nil?
				
				precedence.downcase! if precedence
				
				if spam =~ /yes/i
					
					puts "Skipping #{reply_to}, marked as spam"
					
				elsif reply_to =~ /noreply|donotreply|no-reply/i
					
					puts "Skipping #{reply_to}, sent from a noreply"
					
				elsif [ "bulk", "junk" ].include? precedence
					
					puts "Skipping #{reply_to}, looks like bulk mail"
					
				elsif list_unsub
					
					puts "Skipping #{reply_to}, looks like a mailing list"
					
				elsif @con.already_responded?(email, reply_to)
					
					puts "Skipping #{reply_to}, already emailed"
					
				else
				
					mail_opts = {
						:from => email,
						:from_alias => descname,
						:subject => subject,
						:body => body
					}
					
					send_email(reply_to, mail_opts)
					@con.mark_responded(email, reply_to)
					message.add_flag('R')
					
				end
				
			end
			
		end
		
	end
	
	def header(name, data)
		match = /^#{name}:.(.*)$/.match(data)
		match[1] unless match.nil?
	end
	
	def send_email(to, opts)
		opts[:server] ||= MailConfig::AR_SERVER

		msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: #{to}
Subject: #{opts[:subject]}

#{opts[:body]}
END_OF_MESSAGE

		Net::SMTP.start(opts[:server]) do |smtp|
			smtp.send_message msg, opts[:from], to
		end

	end
	
	def self.run!
		
		ar = AutoResponder.new
		ar.respond
		ar.close
		
	end
	
end
