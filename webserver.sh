#!/usr/bin/env bash

# +-----------------------------------------------------------------------------------------+
# | UBUNTU DEVELOPMENT WEB SERVER FOR RASPBERRY PI 3/4                                      |
# +-----------------------------------------------------------------------------------------+
# | Version : 2.001                                                                         |
# | Date    : 08/JULY/2022                                                                  |
# | Author  : Jon Thompson                                                                  |
# | License : Public Domain                                                                 |
# +-----------------------------------------------------------------------------------------+
# | Installs and configures a basic LAMP stack running under the WSL components             |
# | - 2.001 : Added Apache CHROOT                                                           |
# +-----------------------------------------------------------------------------------------+



# +-----------------------------------------------------------------------------------------+
# | NEEDS TO BE RUN AS ROOT, AS WE ARE INSTALLING PACKAGES                                  |
# +-----------------------------------------------------------------------------------------+
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi



# +-----------------------------------------------------------------------------------------+
# | UPDATE THE SYSTEM AND ADD THE NEW PHP REPOSITORY                                        |
# +-----------------------------------------------------------------------------------------+
echo "RUNNING REPOSITORY UPDATES"
apt install -y software-properties-common language-pack-en-base openssl
LC_ALL=en_GB.UTF-8 add-apt-repository -y ppa:ondrej/php
apt-get update
apt-get -y upgrade



# +-----------------------------------------------------------------------------------------+
# | VARIABLES                                                                               |
# +-----------------------------------------------------------------------------------------+
MYSQLROOTPWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
WEBUSERPWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
SALT=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
WEBUSERPWDHASH=$(openssl passwd -6 -salt ${SALT} ${WEBUSERPWD})
IPADDRESS=$(ip addr show eth0 | grep -oE 'inet [0-9.]+' | cut -d ' ' -f 2)



# +-----------------------------------------------------------------------------------------+
# | INSTALL A FEW UTILITIES                                                                 |
# +-----------------------------------------------------------------------------------------+
apt-get install -y imagemagick curl zip unzip mcrypt ffmpeg jpegoptim optipng mpd mpc
curl --silent -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl 2>&1
chmod a+rx /usr/local/bin/youtube-dl



# +-----------------------------------------------------------------------------------------+
# | GET THE AVAILABLE PHP VERSIONS AND ASK FOR USER INPUT AS TO WHICH ONE TO INSTALL        |
# +-----------------------------------------------------------------------------------------+
mapfile -t PHPVERSIONS < <( apt-cache search --names-only '^php(7|8)\.[0-9]+$' | sort | cut -d ' ' -f 1 )
CT=1

for i in "${PHPVERSIONS[@]}"
do
	echo "${CT} - ${i}"
	CT=$((CT+1))
done

MAXVERSIONS=${#PHPVERSIONS[@]}

while :; do
  read -p "Install which PHP version? (1-${MAXVERSIONS}) : " VERSINPUT
  [[ ${VERSINPUT} =~ ^[0-9]+$ ]] || { echo "Enter a valid number"; continue; }
  if ((VERSINPUT >= 1 && VERSINPUT <= ${MAXVERSIONS})); then
    VERSINPUT=$((VERSINPUT-1))
	PHPVERSION=${PHPVERSIONS[${VERSINPUT}]}
    break
  else
    echo "Invalid selection, please try again"
  fi
done



# +-----------------------------------------------------------------------------------------+
# | INSTALL APACHE                                                                          |
# +-----------------------------------------------------------------------------------------+
apt-get install -y apache2 



# +-----------------------------------------------------------------------------------------+
# | INSTALL PHP                                                                             |
# +-----------------------------------------------------------------------------------------+
apt-get install -y ${PHPVERSION} ${PHPVERSION}-cli ${PHPVERSION}-common ${PHPVERSION}-curl ${PHPVERSION}-gd ${PHPVERSION}-imagick ${PHPVERSION}-imap ${PHPVERSION}-mailparse ${PHPVERSION}-mbstring ${PHPVERSION}-mcrypt ${PHPVERSION}-mysql ${PHPVERSION}-xdebug ${PHPVERSION}-xml ${PHPVERSION}-zip



# +-----------------------------------------------------------------------------------------+
# | INSTALL MARIADB (MYSQL EQUIVALENT)                                                      |
# +-----------------------------------------------------------------------------------------+
apt-get install -y mariadb-client mariadb-server



# +-----------------------------------------------------------------------------------------+
# | SET UP SFTP                                                                             |
# +-----------------------------------------------------------------------------------------+
addgroup sftpusers
useradd -g sftpusers -s /usr/sbin/nologin -d /var/www/websites -p ${WEBUSERPWDHASH} webuser
usermod -aG sudo webuser
chown webuser:sftpusers /var/www/websites -R
find /var/www/websites -type d -exec chmod 0755 {} \;
find /var/www/websites -type f -exec chmod 0644 {} \;
sed -i 's/Subsystem sftp/# Subsystem sftp/' /etc/ssh/sshd_config
chown root: /var/www
chown root: /var/www/websites
cat << _EOF_ >> /etc/ssh/sshd_config


Subsystem sftp internal-sftp
Match Group sftpusers
ForceCommand internal-sftp
ChrootDirectory /var/www/websites
X11Forwarding no
AllowTcpForwarding no
_EOF_



# +-----------------------------------------------------------------------------------------+
# | ENABLE & CONFIGURE MOD_VHOST_ALIAS, SET APACHE TO RUN AS OUR SFTP USER                  |
# +-----------------------------------------------------------------------------------------+
a2enmod vhost_alias 
a2enmod rewrite

sed -i 's/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=webuser/' /etc/apache2/envvars
sed -i 's/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=sftpusers/' /etc/apache2/envvars

cat << _EOF_ > /etc/apache2/sites-available/000-default.conf
<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        VirtualDocumentRoot /var/www/websites/%0/web
        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<Directory /var/www/websites>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
_EOF_



# +-----------------------------------------------------------------------------------------+
# | CREATE EXAMPLE TEST PHP PAGE                                                            |
# +-----------------------------------------------------------------------------------------+
mkdir -p "/var/www/websites/${IPADDRESS}/web/"
cat << _EOF_ > /var/www/websites/${IPADDRESS}/web/index.php
<html>
<head>
<title>Example page</title>
<style>
body {margin: 0; padding: 0;}
h6 {font-size: 2.0em; text-align: center; background-color: #ffa726; padding: 10px;}
</style>
</head>
<body>
<h6>Testing PHP works</h6>
<?php
phpinfo();
?>
</body>
</html>
_EOF_



# +-----------------------------------------------------------------------------------------+
# | CHROOT APACHE                                                                           |
# +-----------------------------------------------------------------------------------------+
mkdir -p /var/www/var/run
chown -R root:root /var/www/var/run
cp /usr/share/apache2/icons /var/www
sed -i 's/PidFile \$\{APACHE_PID_FILE\}/PidFile \$\{APACHE_PID_FILE\}\nChrootDir /var/www/' /etc/apache2/apache2.conf
mkdir -p /var/www/var
ln -s /var/www/ /var/www/var/www
ln -s /var/www/var/run/apache2.pid /var/run/apache2.pid



# +-----------------------------------------------------------------------------------------+
# | SAVE THE MYSQL ROOT PASSWORD IN A CNF FILE FOR USE IN MANAGEMENT SCRIPTS                |
# +-----------------------------------------------------------------------------------------+
service mysql start
cat << _EOF_ > ./.wsl.root_mysql.cnf
[client]
password="${MYSQLROOTPWD}"
_EOF_

chmod 0600 ./.wsl.root_mysql.cnf



# +-----------------------------------------------------------------------------------------+
# | CONFIGURE PHP.INI                                                                       |
# +-----------------------------------------------------------------------------------------+
PHPINI=`php -i | grep 'Loaded Configuration File' | cut -d '>' -f 2 | cut -d ' ' -f 2 | sed 's/cli/apache2/'`
sed -i 's/max_execution_time = 30/max_execution_time = 90/' ${PHPINI}
sed -i 's/post_max_size = 8M/post_max_size = 128M/' ${PHPINI}
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 128M/' ${PHPINI}
sed -i 's/allow_url_fopen = On/allow_url_fopen = Off/' ${PHPINI}
sed -i 's/;date.timezone =/date.timezone = Europe\/London/' ${PHPINI}
sed -i 's/mail.add_x_header = Off/mail.add_x_header = On/' ${PHPINI}



# +-----------------------------------------------------------------------------------------+
# | SECURE MYSQL                                                                            |
# +-----------------------------------------------------------------------------------------+
mysql --user=root <<_EOF_
  UPDATE mysql.user SET Password=PASSWORD('${MYSQLROOTPWD}') WHERE User='root';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  DROP DATABASE IF EXISTS test;
  DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
  FLUSH PRIVILEGES;
_EOF_


# +-----------------------------------------------------------------------------------------+
# | LOGIN INFOR                                                                             |
# +-----------------------------------------------------------------------------------------+
echo " "
echo " +-------------------------------------------------------------------------+"
echo " | SERVER AND LOGIN INFORMATION                                            |"
echo " +-------------------------------------------------------------------------+"
echo " "
echo " IP ADDRESS    : ${IPADDRESS}"
echo " TEST SITE     : http://${IPADDRESS}"
echo " FTP USER      : webuser:${WEBUSERPWD}"
echo " MYSQL ROOT    : root:${MYSQLROOTPWD}"

cat << _EOF_ > ./.logins.txt
IP ADDRESS    : ${IPADDRESS}
TEST SITE     : http://${IPADDRESS}
FTP USER      : webuser:${WEBUSERPWD}
MYSQL ROOT    : root:${MYSQLROOTPWD}
_EOF_

systemctl restart sshd
systemctl restart apache2
