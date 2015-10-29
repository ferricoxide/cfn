#!/bin/sh
#
# Need to activate /tmp as a tmpfs
#
#################################################################

# Check to see if service-control is masked
if [[ "$(systemctl is-enabled tmp.mount)" = "masked" ]]
then
   printf "Removing service-mask from tmp.mount..."
   if [[ $(systemctl unmask tmp.mount) -eq 0 ]]
   then
      echo "Success!"
   else
      echo "Failed! Aborting..." > /dev/stderr
      exit 1
   fi
fi

# Enable tmp.mount service
printf "Enabling /tmp as tmpfs... "
systemctl enable tmp.mount && echo "Success!" || echo "Failed!" > /dev/stderr

# Start tmp.mount service
printf "Mounting /tmp as tmpfs... "
systemctl start tmp.mount && echo "Success!" || echo "Failed!" > /dev/stderr

