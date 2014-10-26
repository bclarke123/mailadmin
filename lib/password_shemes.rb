#!/usr/bin/env ruby
require 'digest'
require 'base64'
require 'securerandom'

############################################
# Implementation of Dovecot's password schemes 
#
# See also http://wiki2.dovecot.org/Authentication/PasswordSchemes
# Based on the password scheme implementations from VBox.Adm - http://developer.gauner.org/vboxadm/ by Dominik Schulz (dominik.schulz@gauner.org)
module Dovecot
  class Password 

    attr_reader :password, :hash, :scheme, :salt_length

    HASH_LENGTH = { 'smd5' => 16, 'ssha' => 20, 'ssha256' => 32, 'ssha512' => 64 }
    SCHEMES = {'hashed' => ['plain', 'plain_md5', 'ldap_md5', 'sha', 'sha256', 'sha512'], 'salted' =>  ['smd5', 'ssha', 'ssha256', 'ssha512']}
    
    def initialize(password, hash=nil, scheme=nil, salt_length=nil)
      @password     = password
      @hash         = hash
      
      if scheme.nil? 
        if !(defined? MailConfig::PASS_SCHEME).nil?
          scheme =  MailConfig::PASS_SCHEME
          raise "The password scheme \"#{scheme}\" which you have defined in lib/config.rb is not supported! Please check the spelling." unless ((SCHEMES['hashed'].include? scheme) || (SCHEMES['salted'].include? scheme))
        else 
          scheme = 'SSHA512'
        end
        @scheme = scheme
      else
        raise "The password scheme \"#{scheme}\" is not supported! Please check the spelling." unless ((SCHEMES['hashed'].include? scheme) || (SCHEMES['salted'].include? scheme))
        @scheme = scheme
      end

      if salt_length.nil? 
        if !(defined? MailConfig::SALT_LENGTH).nil?
          @salt_length =  MailConfig::SALT_LENGTH
        else 
          @salt_length = 8
        end
      end

    end
    
    def password=(password)
      @password = password
    end

    def hash=(hash)
      @hash = hash
    end

    def scheme=(scheme)
      raise "The password scheme \"#{scheme}\" is not supported! Please check the spelling." unless ((SCHEMES['hashed'].include? scheme) || (SCHEMES['salted'].include? scheme))
      @scheme = scheme
    end

    def salt_length=(length)
      @salt_length = length 
    end

    
    # Unsalted password schemes 
    #---------------------------
    
    # MD5 sum of the password stored in hex. 
    def self.plain_md5(password)
      return "{PLAIN-MD5}" + Digest::MD5.hexdigest(password)
    end
    
    # MD5 sum of the password stored in base64. 
    def self.ldap_md5(password)
      return "{LDAP-MD5}" + Digest::MD5.base64digest(password)
    end
    
    # SHA1 sum of the password stored in base64. 
    def self.sha(password)
      return "{SHA}" + Digest::SHA1.base64digest(password)
    end
    
    # SHA256 sum of the password stored in base64. (v1.1 and later). 
    def self.sha256(password)
      return "{SHA256}" + Digest::SHA256.base64digest(password)
    end
    
    # SHA512 sum of the password stored in base64. (v2.0 and later). 
    def self.sha512(password)
      return "{SHA512}" + Digest::SHA512.base64digest(password)
    end
    
    # Salted password schemes 
    #-------------------------
    # With the help of https://gist.github.com/geoffgarside/960927#file-dovecot-password-rb
    
    # Salted MD5 sum of the password stored in base64. 
    def self.smd5(password, salt='', salt_length)
      salt = make_salt(salt_length) if salt == ''
      return "{SMD5}" + Base64.strict_encode64(Digest::MD5.digest(password + salt ) + salt)
    end
    
    # Salted SHA1 sum of the password stored in base64. 
    def self.ssha(password, salt='', salt_length)
      salt = make_salt(salt_length) if salt == ''
      return "{SSHA}" + Base64.strict_encode64(Digest::SHA1.digest(password + salt ) + salt)
    end
    
    # Salted SHA256 sum of the password stored in base64. (v1.2 and later). 
    def self.ssha256(password, salt='', salt_length)
      salt = make_salt(salt_length) if salt == ''
      return "{SSHA256}" + Base64.strict_encode64(Digest::SHA256.digest(password + salt ) + salt)
    end
    
    # Salted SHA512 sum of the password stored in base64. (v2.0 and later). 
    def self.ssha512(password, salt='', salt_length)
      salt = make_salt(salt_length) if salt == ''
      return "{SSHA512}" + Base64.strict_encode64(Digest::SHA512.digest(password + salt ) + salt)
    end

    def get() 
      make_pass(@scheme, @password, '', @salt_length)
    end

    def equal?
      puts 'DEBUG-------------'
      puts "@password = #{@password}\n@hash = #{@hash}"
      self.class.equal(@password, @hash)
    end

    def self.equal(clear_pw, dbhash)
      splitted_hash = split_pass(dbhash)
      puts 'DEBUG-------------'
      puts "@clear_pw = #{clear_pw}\ndbhash = #{dbhash}"
      pp(splitted_hash)
      pw_hash = make_pass(splitted_hash[0], clear_pw, splitted_hash[2])
      if(dbhash == pw_hash)
        return true
      else
        return false
      end
    end

    

    def self.split_pass(hash_string)
      pw_scheme = 'plain'

      # get password scheme 
      regex = /^\{([[A-Z]\d-]*)\}(.*)/
      pw = regex.match(hash_string)
      if pw.nil?
        # Couldn't detect password scheme
        pw_scheme = @scheme.downcase
        hash = hash_string
      else
        pw_scheme = pw[1].gsub('-', '_').downcase
        hash = pw[2]
      end


      # We have 3 major cases:
      # 1 - cleartext pw
      # 2 - hashed pw, no salt
      # 3 - hashed pw with salt

      if pw_scheme == 'plain'
        return ['plain', pw, '']
      elsif SCHEMES['hashed'].include? pw_scheme
        
        # pw_scheme could also specify an encoding
        # like hex or base64, but right now we assume its b64
        hash = Base64.strict_decode64(hash)
        return [pw_scheme, hash, '']
      elsif SCHEMES['salted'].include? pw_scheme
        
        # get the hash length for the given password scheme
        hashlen = HASH_LENGTH[pw_scheme]

        # pw_scheme could also specify an encoding
        # like hex or base64, but right now we assume its b64
        hash = Base64.strict_decode64(hash)

        # unpack byte-by-byte, the has uses the full eight bit of each byte,
        # the salt may do so, too.
        tmp = hash.unpack('C*')

        # the salted hash has the form: $saltedhash.$salt,
        # so the first bytes (# $hashlen) are the hash, the rest
        # is the variable length salt
        pw_hash = tmp[0..(HASH_LENGTH[pw_scheme]-1)]
        pw_salt = tmp[HASH_LENGTH[pw_scheme]..-1]

        # pack it again, byte-by-byte
        pw_hash = pw_hash.pack('C*')
        pw_salt = pw_salt.pack('C*')

        return [pw_scheme, pw_hash, pw_salt]
      end
    end

    def self.make_salt(length) 
      return SecureRandom.random_bytes(length)
    end

    def self.make_pass(scheme, password, salt='', salt_length=8)
      case scheme.downcase
      when 'plain_md5'
        plain_md5(password)
      when 'ldap_md5'
        ldap_md5(password)
      when 'sha'
        sha(password)
      when 'sha256'
        sha256(password)
      when 'sha512'
        sha512(password)
      when 'smd5'
        smd5(password, salt, salt_length)
      when 'ssha'
        ssha(password, salt, salt_length)
      when 'ssha256'
        ssha256(password, salt, salt_length)
      when 'ssha512'
        ssha512(password, salt, salt_length)

      else 
        return @password
      end
    end

  end
end
