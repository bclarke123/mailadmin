class User

	attr_accessor :id, :email, :password, :domain_id, :admin_domains, :super_admin

end

class Domain
	
	attr_accessor :id, :name
	
end

class Alias
	
	attr_accessor :id, :source, :destination, :domain_id
	
end
