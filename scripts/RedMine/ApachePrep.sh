#!/bin/sh
#
# This script installs and configures the CentOS-packaged Apache
# RPMs to support the RedMine installation
#
#################################################################

# Check if we're root..
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
   local ISINSTALLED=$(yum list installed httpd > /dev/null 2>&1)$?

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

## # Configure httpd to support RedMine
## function ConfigApache() {
##    local RETURN=0
##    local HTTPCF="/etc/httpd/conf/httpd.conf"
## 
##    # line 86: change to admin's email address
##    ServerAdmin root@server.world
##    # line 95: change to your server's name
##    ServerName www.server.world:80
##    # line 151: change
##    AllowOverride All
##    # line 164: add file name that it can access only with directory's name
##    DirectoryIndex index.html index.cgi index.php
##    # add follows to the end
##    # server's response header
##    ServerTokens Prod
##    # keepalive is ON
##    KeepAlive On
## }
## 
## # Start/enable Apache
## function MkActive_Apache() {
##    systemctl start httpd 
##    systemctl enable httpd 
## }
## # Create a Welcome page to test remote access to base-Apache
## function TestWelcome() {
##    local RETURN=0
## 
##    cat > /var/www/html/index.html << EOF
## <html>
##   <head
##   <body>
##     <div style="width: 100%; font-size: 40px; font-weight: bold; text-align: center;">
##       Test Page
##     </div>
##   </body>
## </html>
## EOF || local RETURN=1
## 
##   echo ${RETURN}
## }


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

# ConfigApache
# MkActive_Apache
# TestWelcome
