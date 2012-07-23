create table domain_admins (
	domain_id integer references virtual_domains(id),	
	user_id integer references virtual_users(id),
	primary key(domain_id, user_id)
);


