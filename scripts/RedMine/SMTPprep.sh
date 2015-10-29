#!/bin/sh
#
# This script installs and configures the CentOS-packaged PostFix
# RPMs to support the RedMine installation
#
#################################################################
THISHOST="${1:-$(hostname)}"
THISDOMN="$(echo ${THISHOST} | sed 's/'$(hostname -s)'\.//')"
PFXSETS=( 
      "myhostname:${THISHOST}"
      "mydomain:${THISDOMN}"
      'myorigin:$mydomain'
      'inet_interfaces:all'
      'mydestination:$myhostname, localhost.$mydomain, localhost, $mydomain'
      'mynetworks:127.0.0.0/8, 10.0.0.0/24'
      'home_mailbox:Maildir/'
      'smtpd_banner:$myhostname ESMTP'
      'message_size_limit:10485760'
      'mailbox_size_limit:1073741824'
   )

# Check if calling as root..
function AmRoot() {
   if [[ $(whoami) != "root" ]]
   then
      echo "Must be root to use this tool." > /dev/stderr
      exit 1
   fi
}

# Install postfix as needed
function InstallPostfix() {
   local RETURN=0
   local ISINSTALLED=$(rpm --quiet -q postfix)$?

   if [[ ${ISINSTALLED} -eq 0 ]]
   then
      # Postfix already installed
      local RETURN=0
   else
      # Install Apache and set a returnable status
      yum --quiet -y install postfix || local RETURN=1
   fi

   echo "${RETURN}"
}

# Make Postfix settings changes
function CfgPostfix() {
   local RETURN=0
   local PARM="${1}"
   local VAL="${2}"

   postconf -e "${PARM}=${VAL}" > /dev/null 2>&1 || local RETURN=1

   echo "${RETURN}"
}

# Start and enable PostFix
function MkActive_Postfix() {
   local RETURN=0

   systemctl restart postfix || local RETURN=1
   systemctl enable postfix || local RETURN=1

   echo "${RETURN}"
}


##################################
## Define main programatic flow
##################################
LOOP=0
#AmRoot

while [[ ${LOOP} -lt ${#PFXSETS[@]} ]]
do
   ARG1=$(echo ${PFXSETS[${LOOP}]} | cut -d ":" -f 1)
   ARG2=$(echo ${PFXSETS[${LOOP}]} | cut -d ":" -f 2)

   printf "Updating value of ${ARG1}... "
   if [[ $(CfgPostfix "${ARG1}" "${ARG2}") -eq 0 ]]
   then
      echo "Succeeded!"
   else
      echo "Failed!" > /dev/stderr
   fi

   LOOP=$((${LOOP} + 1))
done
