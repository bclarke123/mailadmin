# Postfix Admin Panel

## What?
This is a Sinatra (http://www.sinatrarb.com/) application for administrating
virtual domains, accounts and aliases for Postfix (http://www.postfix.org/) and
Dovecot (http://www.dovecot.org/) as configured using Christoph Haas' exemplary
tutorials found at http://www.workaround.org/ispmail .

## Installation
- Ensure you have ruby, sinatra, ruby-mysql and (optionally, but recommended) 
	thin installed.  The default ruby that ships with Debian has some problems, I
	recommend using RVM with Ruby 1.9.3 for production systems.  Install
	instructions are available at https://rvm.io/rvm/install/ .  Once it's
	running you can	`gem install sinatra thin mysql`
- Download the source either using git or from the GitHub downloads page.
	The latest version will always be at the top of 
	https://github.com/germania/mailadmin/downloads
- Extract the archive somewhere.
- Inside of sql/ is a short SQL script to add a `domain_admins` table, and a
	boolean flag on the users table.  Run this against your Postfix database.
- You will want to set yourself up as a super admin, so you can add domains,
	and administrate all existing ones without having to set yourself as an
	admin for each one.  Assuming you are the first user in the database, run
	`update virtual_users set super_admin = 1 where id = 1;`
- Open `lib/config.rb` and supply your database information.
- You should now be able to	`ruby ./run.rb`
	which should start listening on `localhost:4567`.  Point a browser at it, and
	make sure you can log in with your email and password.
- At this point you have a few options for deployment, I recommend installing
	Passenger with RVM as described at 
	http://everydayrails.com/2011/01/25/passenger-3-rvm.html
	but there is also a provided `daemon.rb` which can be run as an unprivileged
	user and reverse proxied to for the "quick and dirty" approach.
- Add domain admins, make a "change password" link somewhere, and you're ready 
	to go!

## License
> Copyright (c) 2012 Ben Clarke <me@benclarke.ca>
>
> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in
> all copies or substantial portions of the Software.
> 
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
> THE SOFTWARE.