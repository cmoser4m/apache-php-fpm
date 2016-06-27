# update CentOS packages
yum -y update

# devl tools required for compiling
yum -y groupinstall "Development Tools"

# install the EPEL repositories (Extra Packages for Enterprise Linux), required for libmcrypt and other packages - see http://fedoraproject.org/wiki/EPEL
yum -y install epel-release

# install required packages
yum -y install libmcrypt libmcrypt-devel zlib zlib-devel openssl openssl-devel libxml2 libxml2-devel libcurl libcurl-devel libpng libpng-devel pcre-devel libaio

# clean yum cache
yum clean all

# create the www user
adduser --system --create-home www
