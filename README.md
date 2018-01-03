# ADbridge notes repository
Active Directory bridge with Quest - One Identity Authentication Services

This collection of notes has been compiled from 10+ years of deployment experience with Authentication Services from Quest One Identity.

## Known Aliases for Authentication Services
#### Vintela
The parent company aquired by Quest Software in 2005, which pioneered commercial AD bridging solutions provided the acronym VAS for Vintela Authentication Services.

#### Quest Authentication Services
The first of many rebrands of the solution, now many refer to it as QAS, but the underlying application remained largly unchanged. ie: vasclnt, vasgp, vastool, etc.

#### Dell Authentication Services
The Dell rebrand, again just marketing.

#### (New) Quest Authentication Services
Dell sold its software assets to a consortium of VC firms, who rebranded the company back to Quest.

#### One Identity Authentication Services
(New) Quest has spun off the security and identity products and formed a new company, One Identity

#### Aliases
The product hasn't changed beyond customer feature enhancements and bug fixes, yet it has been known by many names:
* Vintela
 * VAS
* Quest Authentication Services
 * QAS
* Dell Authentication Services
 * VAS
* One Identity Authentication Services
 * VAS

## Useful VAS Commands
#### VAS and AD info
```
# To locate the computer object DN in AD
/opt/quest/bin/vastool -u host/ info id

# Info about the current schema
vastool schema list

# Find user objects in AD
vastool -u host/ search -b "dc=strategic,dc=ad" "(objectCategory=person)" cn userPrincipalName
vastool -u host/ search -b "dc=strategic,dc=ad" "(sAMAccountName=mike)"
# User attributes with debug
vastool -d5 -u host/ attrs mike
sudo vastool -u host/ attrs mike name uidnumber gidnumber gecos unixhomedirectory loginshell
sudo vastool -u host/ list -la users

# To list AD Unix enabled users from AD directly:
/opt/quest/bin/vastool -u host/ list -l users
# To list all users including non-enabled users from AD:
/opt/quest/bin/vastool -u host/ list -la users


# Locate AD Group members
vastool -u host/ search "(&(grouptype=*)(samaccountname=unixusr))" member
vastool list group unixusr
vastool -u host/ attrs unixadm member
vastool -u host/ nss getgrnam unixadm
vastool group admins hasmember jsmith
# List only group names
sudo vastool -u host/ attrs unix-AD-group member|cut -f2 -d:|cut -f1 -d,|cut -f1 -d-|cut -f2 -d=

# vastool info
vastool info acl
vastool info adsecurity
vastool info cldap strategic.ad
vastool info domain
vastool info domain-dn
vastool info id -u mike
vastool info servers -d strategic.ad
```
