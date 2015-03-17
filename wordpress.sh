#!/bin/bash
#
# Install WordPress on a Debian/Ubuntu VPS - NGINX
# Allows for multiple installs - Modified by Marcus Lewis 3.10.2015
# Installs wordpress in /var/www/thedomain.ext/wordpress, and configures NGINX

# Create MySQL database
read -p "Enter your MySQL root password: " rootpass  
read -p "Database name: " dbname  
read -p "Database username: " dbuser  
read -p "Enter a password for user $dbuser [no single or double quotes, special characters]:" userpass  
echo "CREATE DATABASE $dbname;" | mysql -u root -p$rootpass  
echo "Database created...\n"  
echo "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$userpass';" | mysql -u root -p$rootpass  
echo "Database user created...\n"  
echo "GRANT ALL PRIVILEGES ON $dbname.* TO $dbuser@localhost;" | mysql -u root -p$rootpass  
echo "Privileges granted...\n"  
echo "FLUSH PRIVILEGES;" | mysql -u root -p$rootpass  
echo "New MySQL database is successfully created"

# Download, unpack and configure WordPress
read -r -p "Enter your WordPress URL? [e.g. mywebsite.com]: " wpURL  
mkdir /var/www/$wpURL && cd  /var/www/$wpURL

wget -q -O - "http://wordpress.org/latest.tar.gz" | tar -xzf -  
chown www-data: -R /var/www/$wpURL/wordpress/ # Give server ownership for now  
cd /var/www/$wpURL/wordpress

cp wp-config-sample.php wp-config.php  
chmod 640 wp-config.php # Keep this file safe  
mkdir uploads

grep -A 1 -B 50 'since 2.6.0' wp-config-sample.php > wp-config.php  
curl https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php  
grep -A 50 -B 3 'Table prefix' wp-config-sample.php >> wp-config.php  
sed -i "s/database_name_here/$dbname/;s/username_here/$dbuser/;s/password_here/$userpass/" wp-config.php

#chown $USER:www-data -R * # Change user to current, group to server  
chown www-data:www-data -R * # Change user to server, group to server  
find . -type d -exec chmod 755 {} \;  # Change directory permissions rwxr-xr-x  
find . -type f -exec chmod 644 {} \;  # Change file permissions rw-r--r--  
chown www-data:www-data wp-content    # Let server be owner of wp-content


# Create nginx virtual host
echo "  
###### $wpURL ######

server {  
    listen 80;
    server_name *.$wpURL $wpURL;

    client_max_body_size 200M;
    root /var/www/$wpURL/wordpress/;


    rewrite ^/(.*.php)(/)(.*)$ /\$1?file=/\$3 last;
    index index.htm index.html index.php;
    autoindex on;

    location / {
        try_files \$uri \$uri/ /index.php?q=\$request_uri;
   }

    location ~ \.php$ {
            include fastcgi.conf;

            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass  127.0.0.1:9000;
            fastcgi_read_timeout 999;
            fastcgi_index index.php;
    }

    if (!-e \$request_filename) {
            set \$filephp 1;
    }


   # if the missing file is a php folder url
    if (\$request_filename ~ \"\.php/\") {
            set \$filephp \"\${filephp}1\";
    }

    if (\$filephp = 11) {
            rewrite  ^(.*).php/.*$  /\$1.php  last;
            break;
    }
}
" >> /etc/nginx/sites-available/$wpURL


# Enable the site
ln -s /etc/nginx/sites-available/$wpURL /etc/nginx/sites-enabled/$wpURL  
service nginx reload

# Output
WPVER=$(grep "wp_version = " /var/www/$wpURL/wordpress/wp-includes/version.php |awk -F\' '{print $2}')  
echo -"\nWordPress version $WPVER is successfully installed!"  
echo  "\nPlease go to http://$wpURL and finish the installation.\n"
