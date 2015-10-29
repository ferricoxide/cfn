#!/bin/sh
#
# This script installs any missing dependencies to support the
# installation of RedMine
#
#################################################################

KNOWNDEPS=(
      mariadb
      ImageMagick
      ImageMagick-devel
      libcurl-devel
      httpd-devel
      mariadb-devel
      ipa-pgothic-fonts
      cyrus-sasl
   )

NEEDDEPS=""

# Check to see which dependencies remain to be satisfied
for DEPCHK in ${KNOWNDEPS[@]}
do
   if [[ $(rpm --quiet -q "${DEPCHK}") -ne 0 ]]
   then
      NEEDDEPS="${NEEDDEPS} + ${DEPCHK}"
   fi
done

# Install remaining dependencies
printf "Installing ${NEEDDEPS}... "
if [[ $(yum --quiet install -y "${NEEDDEPS}" )$? -eq ]]
then
   echo "Success!"
else
   echo "Failed!" > /dev/stderr
fi
