#!/bin/sh
#
# This script installs and configures the CentOS-packaged Apache
# RPMs to support the RedMine installation
#
#################################################################
THISHOST="${1:-$(hostname)}"

# Check if calling as root..
function AmRoot() {
   if [[ $(whoami) != "root" ]]
   then
      echo "Must be root to use this tool." > /dev/stderr
      exit 1
   fi
}

# Install HTTPD services
function InstallApache() {
   local RETURN=0
   local ISINSTALLED=$(rpm --quiet -q httpd)$?

   if [[ ${ISINSTALLED} -eq 0 ]]
   then
      # Apache already installed
      local RETURN=0
   else
      # Install Apache and set a returnable status
      yum --quiet -y install httpd || local RETURN=1
   fi

   echo "${RETURN}"
}

# remove welcome page
function NukeDefWelcome() {
   local RETURN=0

   rm -f /etc/httpd/conf.d/welcome.conf > /dev/null 2>&1 || local RETURN=1

   echo "${RETURN}"
}

# Configure httpd to support RedMine
function ConfigApache() {
   local RETURN=0
   local HTTPCF="/etc/httpd/conf/httpd.conf"

   # Set ServerAdmin value
   if [[ $(grep -qE '^[ ]*ServerAdmin' ${HTTPCF})$? -eq 0 ]]
   then
      sed -i '/^[ ]*ServerAdmin/{
         s/ServerAdmin.*/ServerAdmin root@'${THISHOST}'/
      }' ${HTTPCF} || local RETURN=1
   else
      sed -i '/^#.*ServerAdmin/,/^$/{
         s/^$/ServerAdmin root@'${THISHOST}'\n/
      }' ${HTTPCF} || local RETURN=1
   fi

   # Set ServerName value
   if [[ $(grep -qE '^[ ]*ServerName' ${HTTPCF})$? -eq 0 ]]
   then
      sed -i '/^[ ]*ServerName/{
         s/ServerName.*/ServerName '${THISHOST}':80/
      }' ${HTTPCF} || local RETURN=1
   else
      sed -i '/^#.*ServerName/,/^$/{
         s/^$/ServerName '${THISHOST}':80\n/
      }' ${HTTPCF} || local RETURN=1
   fi

   # Set AllowOverride value
   if [[ $(grep -qE '^[ ]*AllowOverride' ${HTTPCF})$? -eq 0 ]]
   then
      sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/{
         /^[ ]*AllowOverride/{
            s/AllowOverride.*/AllowOverride All/
         }
      }' ${HTTPCF} || local RETURN=1
   else
      sed -i '/<Directory "\/var\/www\/html">/,/<\/Directory>/{
         /^#.*AllowOverride/,/^$/{
            s/^$/AllowOverride All\n/
         }
      }' ${HTTPCF} || local RETURN=1
   fi

   # Set DirectoryIndex value in DocumentRoot
   sed -i '/<IfModule dir_module>/,/<\/IfModule>/{
      /^[ ]*DirectoryIndex/{
         s/DirectoryIndex.*/DirectoryIndex index.php index.cgi index.html/
      } 
   }' ${HTTPCF} || local RETURN=1

   echo "ServerTokens Prod" >> ${HTTPCF} || local RETURN=1
   echo "KeepAlive On" >> ${HTTPCF} || local RETURN=1

   echo "${RETURN}"
}

# Start/enable Apache
function MkActive_Apache() {
   local RETURN=0

   systemctl start httpd || local RETURN=1
   systemctl enable httpd || local RETURN=1

   echo "${RETURN}"
}

# Create a Welcome page to test remote access to base-Apache
function TestWelcome() {
   local RETURN=0

   cat > /var/www/html/index.html << EOF
<html>
  <title>
    Test Page
  </title>
  <body>
    <div style="width: 100%; font-size: 40px; font-weight: bold; text-align: center;">
      Test Page
    </div>
  </body>
</html>
EOF || local RETURN=1

  echo ${RETURN}
}


##############################
## Define main program-flow
##############################

# Bail if we're not run as root...
AmRoot

# Verify Apache installation-status
if [[ $(InstallApache) -eq 0 ]]
then
   echo "Apache httpd packages installed"
else
   echo "Apache httpd packages not correctly installed" > /dev/stderr
fi

# Nuke the default Apache welcome page
if [[ $(NukeDefWelcome) -eq 0 ]]
then
   echo "Removed default welcome page".
else
   echo "Failed to remove default welcome page" > /dev/stderr
fi

# Set RedMine-supporting Apache directives
if [[ $(ConfigApache) -eq 0 ]]
then
   echo "Apache configured for RedMine"
else
   echo "One or more Apache config-mods failed" > /dev/stderr
fi

MkActive_Apache
TestWelcome
