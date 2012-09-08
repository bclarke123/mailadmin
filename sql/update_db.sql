create table domain_admins (
	domain_id integer references virtual_domains(id),	
	user_id integer references virtual_users(id),
	primary key(domain_id, user_id)
);

alter table virtual_users add column super_admin boolean default false;

create table autoresponder_recipients (
	user_email varchar(255) not null references autoresponder(email),
	recipient_email varchar(255) not null,
	send_date datetime not null,
	primary key(user_email, recipient_email)
);
