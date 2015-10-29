#!/bin/sh
#
# Use iptables instead of firewalld
#
#################################################################
export PATH=/sbin:/usr/sbin:/bin:/usr/bin

# Ensure firewalld is disabled
if [[ $(rpm --quiet -q firewalld)$? -eq 0 ]]
then
   systemctl stop firewalld.service > /dev/null 2>&1
   systemctl disable firewalld.service > /dev/null 2>&1
fi

# Install iptables services as necessary
printf "Checking if iptables service is available... "
if [[ $(rpm --quiet -q iptables-services)$? -eq 0 ]]
then
   echo "Installed"
else
   print "Attempting install..."
   if [[ $(yum --quiet install -y iptables-services)$? -eq 0 ]]
   then
      echo "Success!"
      RETURN=0
   else
      echo "Failed! Exiting..." > /dev/stderr
      RETURN=1
      exit ${RETURN}
   fi
fi

# Start the iptables service and add rules
if [[ $(systemctl start iptables.service)$? -eq 0 ]]
then
   iptables -N SSHrules || RETURN=$((${RETURN} + 1))
   iptables -N MailRules || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -m state --state RELATED,ESTABLISHED -m comment --comment "Allow related and established connections" -j ACCEPT || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -i lo -j ACCEPT || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -d 127.0.0.0/8 -i eth0 -j DROP || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -p tcp -m tcp -m multiport --dports 80,443 -m comment --comment "HTTP & HTTPS" -j ACCEPT || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -j SSHrules || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -j MailRules || RETURN=$((${RETURN} + 1))
   iptables -A INPUT -j LOG --log-prefix "Misc IPTABLES Reject: " || RETURN=$((${RETURN} + 1))
   iptables -A MailRules -p tcp -m tcp --dport 25 -m comment --comment "Standard SMTP Port" -j ACCEPT || RETURN=$((${RETURN} + 1))
   iptables -A MailRules -p tcp -m tcp --dport 587 -m comment --comment "SMTP (TLS-encrypted) Submission Port" -j ACCEPT || RETURN=$((${RETURN} + 1))
   iptables -A MailRules -p tcp -m tcp --dport 993 -m comment --comment "SSL-encrypted IMAP Port" -j ACCEPT || RETURN=$((${RETURN} + 1))
   iptables -A SSHrules -p tcp -m state --state NEW -m tcp -m multiport --dports 22 -m recent --set --name sshattack --mask 255.255.255.255 --rsource || RETURN=$((${RETURN} + 1))
   iptables -A SSHrules -p tcp -m tcp -m multiport --dports 22 -m state --state NEW -m recent --update --seconds 300 --hitcount 3 --name sshattack --mask 255.255.255.255 --rsource -j LOG --log-prefix "SSH REJECT: " || RETURN=$((${RETURN} + 1))
   iptables -A SSHrules -p tcp -m tcp -m multiport --dports 22 -m state --state NEW -m recent --update --seconds 300 --hitcount 3 --name sshattack --mask 255.255.255.255 --rsource -j DROP || RETURN=$((${RETURN} + 1))
   iptables -A SSHrules -p tcp -m tcp -m multiport --dports 22 -j ACCEPT || RETURN=$((${RETURN} + 1))
else
   echo "Failed to start iptables"
   exit 1
fi

# Have iptables configured at next boot
if [[ ${RETURN} -eq 0 ]]
then
   echo "Saving and persisting rules and firewall state"
   service iptables save || RETURN=$((${RETURN} + 1))
   systemctl enable iptables.service || RETURN=$((${RETURN} + 1))

   if [[ ${RETURN} -eq 0 ]]
   then
      echo "Successfully configured iptables"
   else
      echo "Something went wrong while configuring iptables." > /dev/stderr
      exit "${RETURN}"
   fi
else
   echo "Failed to add ${RETURN} rules. Configuration will not be persisted." > /dev/stderr
   exit "${RETURN}"
fi
