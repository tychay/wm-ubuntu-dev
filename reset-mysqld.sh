#!/bin/bash
# vim:set tabstop=4 shiftwidth=4 softtabstop=4 foldmethod=marker:
#
# This will reset your mysqld server (from scratch)
#

# To use, run
# $ ./reset-mysqld.sh

# Set up environment {{{
SUDO='sudo'
# }}}
# functions {{{
check_dpkg() { dpkg -l $1 | grep ^ii | wc -l; }
is_eth0() { ifconfig | grep eth0 | wc -l; }
get_ip() { ifconfig | grep 'inet addr' |  awk -F: '{ print $2 }' | awk '{ print $1 }' | grep -v 127.0.0.1; }
pear_installed () { pear list -a | grep ^$1 | wc -l ; }
PHP_EXT_TEST=./extension_installed.php
# {{{  pecl_update_or_install()
# $1 = package name
# $2 = package name in pecl (may have -beta or the like)
# $3 = if set, package name in ubuntu
pecl_update_or_install () {
	if [ `$PHP_EXT_TEST $1` ]; then
		if [ $DO_UPGRADE ]; then
			if [ "$3" != '' ]; then
				echo "### Updating $1...";
				$SUDO apt-get update $3
			else
				echo "### Upgrading $1...";
				$SUDO pecl upgrade $2
			fi
		fi
	else
		echo "### Installing $1...";
		if [ "$3" != '' ]; then
			$SUDO apt-get install $3
		else
			$SUDO pecl install $2
			if [ "$1" = 'xdebug' ]; then
				echo '### Be sure to add to your php.ini: zend_extension="<something>/xdebug.so" NOT! extension=xdebug.so'
			else
				echo "### Be sure to add to your php.ini: extension=$1.so"
				# Let's add config for stuff manually
				echo "extension=${1}.so" | $SUDO tee /etc/php5/conf.d/${1}.ini
				$SUDO cp /etc/php5/conf.d/${1}.ini /etc/php5/conf.d/${1}.ini
			fi
		fi
		PACKAGES_INSTALLED="$1 $PACKAGES_INSTALLED"
	fi
}
# }}}
# }}}
IP_ADDRESS=`get_ip`
echo "### Your IP address is ${IP_ADDRESS}"
# Purge MYSQL {{{
# http://stuffthatspins.com/2011/01/08/ubuntu-10-x-completely-remove-and-clean-mysql-installation/
$SUDO apt-get --purge remove mysql-server mysql-client mysql-common
$SUDO apt-get autoremove
$SUDO apt-get autoclean
# }}}
echo "### Now run ./bootstrap.sh to reinstall (safely)"
exit;
	- http://stuffthatspins.com/2011/01/08/ubuntu-10-x-completely-remove-and-clean-mysql-installation/
	- $ apt-get --purge remove mysql-server mysql-client mysql-common
	- $ apt-get autoremove
	- $ apt-get autoclean
# Install MySQL and phpMyAdmin {{{
# http://www.howtoforge.com/ubuntu_lamp_for_newbies
if [ `check_dpkg mysql-server` = 0 ]; then
	echo "### Installing mysql..."
	$SUDO apt-get install mysql-server
	echo "### (Optional) May want to add"
	echo "bind-address = ${IP_ADDRESS}"
	echo -n "### so outside IPs can bind:"
	read IGNORE
	if [ $EDITOR == '/usr/bin/vim' ]; then
		$SUDO $EDITOR /etc/mysql/my.cnf +53
	else
		$SUDO $EDITOR /etc/mysql/my.cnf
	fi
	sudo service mysql restart
fi
if [ `check_dpkg phpmyadmin` = 0 ]; then
	echo "### Installing phpmyadmin interfaces..."
	$SUDO apt-get install libapache2-mod-auth-mysql php5-mysql phpmyadmin
	$SUDO service apache2 graceful
	echo -n "### Test out PHPMyAdmin by going to http://${IP_ADDRESS}/phpmyadmin/:"
	read IGNORE
fi
echo "### MySQL installed"
# }}}
