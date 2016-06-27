# update CentOS packages
yum -y update

# devl tools required for compiling
yum -y groupinstall "Development Tools"

# install the EPEL repositories (Extra Packages for Enterprise Linux), required for libmcrypt and other packages - see http://fedoraproject.org/wiki/EPEL
yum -y install epel-release

# install required packages
yum -y install libmcrypt libmcrypt-devel zlib zlib-devel openssl openssl-devel libxml2 libxml2-devel libcurl libcurl-devel libpng libpng-devel pcre-devel

# create the www user
adduser --system --create-home www

# copy and extract build files to /root/build directory
cd /root/build
tar zxvf apr-1.5.2.tar.gz && tar zxvf apr-util-1.5.4.tar.gz && tar zxvf httpd-2.4.20.tar.gz && tar zxvf php-7.0.6.tar.gz
unzip instantclient-basic-linux.x64-12.1.0.2.0.zip && unzip instantclient-sdk-linux.x64-12.1.0.2.0.zip

#### ORACLE INSTANT CLIENT

cd /root/build/instantclient_12_1
ln -s libclntsh.so.12.1 libclntsh.so
cd /root/build
mv instantclient_12_1 /usr/local/instantclient
echo "/usr/local/instantclient" >> /etc/ld.so.conf.d/instantclient.conf


#### APACHE HTTPD AND RELATED

# build apr (required for compiling apache)
cd /root/build/apr-1.5.2
./configure && make && make install

# build apr-util (required for compiling apache)
cd /root/build/apr-util-1.5.4
./configure --with-apr=/usr/local/apr && make && make install

# build apache httpd
cd /root/build/httpd-2.4.20
./configure --enable-ssl && make && make install

# enable required apache modules
/usr/local/apache2/bin/apxs -ea -n proxy mod_proxy.so
/usr/local/apache2/bin/apxs -ea -n proxy_fcgi mod_proxy_fcgi.so
/usr/local/apache2/bin/apxs -ea -n rewrite mod_rewrite.so

# add additional Listen directive for port 443 (https)
echo "Listen 443" >> httpd.conf

# activate httpd.conf in the /home/www directory (all projects should have httpd.conf)
echo "Include \"/home/www/httpd.conf\"" >> /usr/local/apache2/conf/httpd.conf

#### PHP AND RELATED

# build php
cd /root/build/php-7.0.6
./configure --with-curl --with-zlib --with-openssl --enable-mbstring=all --with-mcrypt --enable-fpm --with-fpm-user=www --with-fpm-group=www --exec-prefix=/usr/local --enable-zip && make -j 4 && make install

# copy php-fpm init scripts
cd /root/build/php-7.0.6/sapi/fpm
cp init.d.php-fpm /etc/init.d/php-fpm
chmod +x /etc/init.d/php-fpm

#### PHP EXTENSIONS (PDO_OCI and PCNTL)
cd /root/build/php-7.0.6/ext/pdo_oci
phpize && ./configure --with-pdo-oci=instantclient,/usr/local/instantclient,12.1 && make && make install

cd /root/build/php-7.0.6/ext/pcntl
phpize && ./configure && make && make install

rm -rf /root/build/