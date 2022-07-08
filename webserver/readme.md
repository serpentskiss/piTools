# webserver.sh
#### Set up a development web server on a Raspberry Pi 3 or 4

This bash script is intended for use on a Raspberry Pi 4 (or 3), running Ubuntu Server

Features:
- choice of installing any of the PHP versions available in the repos
- MariaDB
- chroot'd Apache2
- multipe virtual hosts using mod_vhost_alias

ToDo:
- support for Let's Encrypt
- scripts to handle directory and database creation

#### Example usage scenario

This is actually my use-case. As the server will only be available on my private internal network, and we're running mod_vhost_alias, I've created a wildcard DNS entry on a real domain name, pointed to the IP address the server is running on. The IP address is reserved in my internal DHCP resolver (PiHole) via the MAC address

- DNS entry: \*.web.example.com A 192.168.0.xxx

As we're using mod_vhost_alias, we don't need to set up any additional vhost entries like we would on a basic Apache server. mod_vhost_alias is set up to look for sites under /var/www/websites/

To add a new site
- sudo mkdir -p /var/www/websites/mysite.web.example.com/web/
- sudo chown -R webuser:sftpusers /var/www/websites/mysite.web.example.com/web/
