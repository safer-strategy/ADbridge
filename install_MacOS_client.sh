#!/bin/bash
# Install the mac VAS client from the command line

# mount the dmg file
hdiutil attach /<some location>/VAS-4.1.*.dmg

# install the package
/usr/sbin/installer -pkg /Volumes/VAS-Installer/VAS.mpkg/ -target /

# detach the volume
hdiutil detach /Volumes/VAS-Installer

# join the host to the AD domain
/opt/quest/bin/vastool -u <ad admin> join -c "ou=macos,ou=workstations,dc=strategic,dc=ad" strategic.ad

