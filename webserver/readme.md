# webserver.sh

#### Set up a development web server on a Raspberry Pi 3 or 4
This bash script is intended for use on a Raspberry Pi 4 (or 3), running Ubuntu Server, and hosted on an internal private network. It _should_ work on any server/VM running Ubuntu Server, but hasn't been tested.

#### Disclaimer
This is provided as-is, use at your own risk.

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
- connect using the SFTP details found in the ubuntu users' home directory (created during the installation of the script)
- upload your web site to the `/mysite.web.example.com/web` folder

To visit the new site in a web browser, there's no need to restart Apache, simply go to `http://mysite.web.example.com`
