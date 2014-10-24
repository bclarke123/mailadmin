#!/usr/bin/env ruby
require 'digest'
require 'base64'
require 'securerandom'


class PassShemes 
  ############################################
  # Implementation of Dovecot's password shemes 
  #
  # See also http://wiki2.dovecot.org/Authentication/PasswordSchemes
  #
  @@hash_lengh = { 'smd5' => 16, 'sshd' => 20, 'ssha256' => 32, 'ssha512' => 64 }
  @@salt_length = 8

  def initialize(password, hash)
    @password = password
    @hash     = hash
  end
  
  # Unsalted password shemes 
  #---------------------------
  
  # MD5 sum of the password stored in hex. 
  def plain_md5
    return "{PLAIN-MD5}" + Digest::MD5.hexdigest(@password)
  end
  
  # MD5 sum of the password stored in base64. 
  def ldap_md5
    return "{LDAP-MD5}" + Digest::MD5.base64digest(@password)
  end
  
  # SHA1 sum of the password stored in base64. 
  def sha
    return "{SHA}" + Digest::SHA1.base64digest(@password)
  end
  
  # SHA256 sum of the password stored in base64. (v1.1 and later). 
  def sha256
    return "{SHA256}" + Digest::SHA256.base64digest(@password)
  end
  
  # SHA512 sum of the password stored in base64. (v2.0 and later). 
  def sha512
    return "{SHA512}" + Digest::SHA512.base64digest(@password)
  end
  
  # Salted password shemes 
  #-------------------------
  
  # Salted MD5 sum of the password stored in base64. 
  def smd5
    salt = make_salt()
    return "{SMD5}" + Base64.urlsafe_encode64(Digest::MD5.digest(@password + salt ) + salt)
  end
  
  # Salted SHA1 sum of the password stored in base64. 
  def ssha
    salt = make_salt()
    return "{SSHA}" + Base64.urlsafe_encode64(Digest::SHA1.digest(@password + salt ) + salt)
  end
  
  # Salted SHA256 sum of the password stored in base64. (v1.2 and later). 
  def ssha256
    salt = make_salt()
    return "{SSHA256}" + Base64.urlsafe_encode64(Digest::SHA256.digest(@password + salt ) + salt)
  end
  
  # Salted SHA512 sum of the password stored in base64. (v2.0 and later). 
  def ssha512
    salt = make_salt()
    "{SSHA512}" + Base64.urlsafe_encode64(Digest::SHA512.digest(@password + salt ) + salt)
  end


  def make_salt() 
    return SecureRandom.random_bytes(@@salt_length)
  end

end
