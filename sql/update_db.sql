create table domain_admins (
	domain_id integer references virtual_domains(id),	
	user_id integer references virtual_users(id),
	primary key(domain_id, user_id)
);

alter table virtual_users add column super_admin boolean default false;

CREATE TABLE `autoresponder` (
	`email` varchar(255) NOT NULL default '',
	`descname` varchar(255) default NULL,
	`from` date NOT NULL default '0000-00-00',
	`to` date NOT NULL default '0000-00-00',
	`message` text NOT NULL,
	`enabled` tinyint(4) NOT NULL default '0',
	`subject` varchar(255) NOT NULL default '',
	PRIMARY KEY (`email`),
	FULLTEXT KEY `message` (`message`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

create table autoresponder_recipients (
	user_email varchar(255) not null references autoresponder(email),
	recipient_email varchar(255) not null,
	send_date datetime not null,
	primary key(user_email, recipient_email)
);
