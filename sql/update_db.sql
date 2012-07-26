create table domain_admins (
	domain_id integer references virtual_domains(id),	
	user_id integer references virtual_users(id),
	primary key(domain_id, user_id)
);

alter table virtual_users add column super_admin boolean default false;
