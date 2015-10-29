#!/bin/sh
#
# This script installs and configures the CentOS-packaged MariaDB
# RPMs to support the RedMine installation.
#
# Note: Do not use this script if making use of a Maria/MySQL
#       database hosted external to the RedMine service.
#
#################################################################
DBPASSWD="${1:-${DBPASSWD}}"
THISHOST="${2:-$(hostname)}"

# Check if calling as root..
function AmRoot() {
   if [[ $(whoami) != "root" ]]
   then
      echo "Must be root to use this tool." > /dev/stderr
      exit 1
   fi
}

function InstallMariaDB() {
   local RETURN=0
   local ISINSTALLED=$(yum list installed mariadb-server > /dev/null 2>&1)$?

   if [[ ${ISINSTALLED} -eq 0 ]]
   then
      # MariaDB already installed
      local RETURN=0
   else
      # Install MariaDB and set a returnable status
      yum --quiet -y install mariadb-server || local RETURN=1
   fi

   echo "${RETURN}"
}

# Set config options
function ConfigMaria() {
   local RETURN=0
   local SQLCF="/etc/my.cnf"

   sed -i '/\[mysqld\]/,/\[/{
      s/^$/character-set-server=utf8\n/
   }' "${SQLCF}" || local RETURN=1

   echo "${RETURN}"
}

# Safe-up MariaDB
function SafeMaria() {
   local RETURN=0
   local PASSWD="${1}"

   echo -e "\n\n${PASSWD}\n${PASSWD}\n\n\nn\n\n " | \
      mysql_secure_installation > /dev/null 2>&1 || local RETURN=1

   echo "${RETURN}"
}

# Start/enable MariaDB
function MkActive_MariaDB() {
   local RETURN=0

   systemctl start mariadb || local RETURN=1
   systemctl enable mariadb || local RETURN=1

   echo "${RETURN}"
}


#######################
## Main program-flow
#######################

# Bomb if not root
AmRoot

# Verify that MariaDB is installed
if [[ $(InstallMariaDB) -eq 0 ]]
then
   echo "MariaDB is installed."
else
   echo "MariaDB not properly installed" > /dev/stderr
   exit 1
fi

# Configure MariaDB parameters
printf "Setting MariaDB run-parameters... "
if [[ $(ConfigMaria) -eq 0 ]]
then
   echo "Success!"
else
   echo "Failed!" > /dev/stderr
fi

# Enable MariaDB's systemd controls
printf "Using systemd to start/enable MariaDB... "
if [[ $(MkActive_MariaDB) ]]
then
   echo "Sucess!"
else
   echo "Failed!" > /dev/stderr
   exit 1
fi

# Run mysql_secure_installation to safe the MariaDB instance
printf "Running mysql_secure_installation to set password to '${DBPASSWD}'... "
if [[ $(SafeMaria "${DBPASSWD}") -eq 0 ]]
then
   echo "Success!"
else
   echo "Failed!" > /dev/stderr
fi
