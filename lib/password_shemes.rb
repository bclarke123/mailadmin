#!/usr/bin/env ruby

class PassShemes 
  ############################################
  # Implementation of Dovecot's password shemes 
  #
  # See also http://wiki2.dovecot.org/Authentication/PasswordSchemes
  #
  
  def initialize(password, hash)
    @password = password
    @hash     = hash
  end
  
  # Unsalted password shemes 
  #---------------------------
  
  # MD5 sum of the password stored in hex. 
  def plain_md5
  
    return "{PLAIN-MD5}"
  end
  
  # MD5 sum of the password stored in base64. 
  def ldap_md5
  
  end
  
  # SHA1 sum of the password stored in base64. 
  def sha
  
  end
  
  # SHA256 sum of the password stored in base64. (v1.1 and later). 
  def sha256
  
  end
  
  # SHA512 sum of the password stored in base64. (v2.0 and later). 
  def sha512
  
  end
  
  # Salted password shemes 
  #-------------------------
  
  # Salted MD5 sum of the password stored in base64. 
  def smd5
  
  end
  
  # Salted SHA1 sum of the password stored in base64. 
  def ssha
  
  end
  
  # Salted SHA256 sum of the password stored in base64. (v1.2 and later). 
  def ssha256
  
  end
  
  # Salted SHA512 sum of the password stored in base64. (v2.0 and later). 
  def ssha512
  
  end

end
