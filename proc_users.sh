#!/bin/bash
# This script uses the Ownership Alignment Tools (OAT) included with the VAS distribution
# to process files under /home changing the ownership to match POSIX data stored in AD.
# It's likely that it will need some level of customization to function in YOUR environment
# Please contact mike@saferstrategy.com
# ALL RIGHTS RESERVED

# Global Vars
working_dir=$(basename $(cd $(dirname $0) && pwd))
containing_dir=$(cd $(dirname $0)/.. && pwd)
basename="${containing_dir}/${working_dir}"
myname=`basename "$0"`
Date=`date "+%Y-%m-%d"`
Epoch=`date "+%s"`
os_name=`uname -s`
Hostname=`hostname|cut -f1 -d.`

# Site Vars
joiner_keytab="$basename/.secure/unixadjnusr.keytab"
VAStool="/opt/quest/bin/vastool"
joiner="joinerSVC-unixad@DOMAIN.COM"
VAScreds="-u $joiner -k $joiner_keytab"

# Script Vars
# Specify the directory to create to store the backup for rollback and file history.
# Place this where it will be archived for disaster recovery
OATBACKUP="/var/opt/quest/oat/oatwork"
#OATBACKUP="./oatwork"
# Specify the directory to process with OAT
PROCDIR="/home"
# Password file to use for input
Passwd="/etc/passwd"
# Location of Group file to process
Group="/etc/group"
# Location to pre-created usermap file
Usermap="/etc/usermap"
# Users on localhost matched by OATmatched
OATmatchedUsers="./matched_users.txt"
# Groups on localhost matched by OATmatched
OATmatchGroups="./matched_groups.txt"
FindGroups="./user_groups.txt"
# All current Unix Enabled AD users/groups (File is auto-generated)
ADusers="./oat_aduser.txt"
ADgroups="./oat_adgroups.txt"
# A list of the Groups purged from /etc/group
GroupsPurged="$OATBACKUP/groups_purged.txt"
# Home Directory Rollback Script (called by rollback arg)
HomeRollback="$OATBACKUP/Home_rollback.sh"


Main(){
  pull_AD
  match_oat
  matched_User_Groups
  if [ "$1" = "test" ];then
    test_oat
    purge_group_test
  elif [ "$1" = "commit" ]; then
    commit_oat
    purge_group
    mod_Homedir
  elif [ "$1" = "rollback" ]; then
    rollback_oat
  else
    printHelp
  fi
}

printHelp(){
  cat << EOT

  Usage: $myname [ test | commit | rollback ]
  Creates $ADusers, $ADgroups, $OATmatchedUsers and $OATmatchGroups in current directory.

EOT
}

#-- prompt user for information
#   usage: query prompt varname [default]
query () {
    eval $2=
    while eval "test ! -n \"\$$2\""; do
        if read xx?yy <$0 2>/dev/null; then
            eval "read \"$2?$1${3+ [$3]}: \"" || die "(end of file)"
        else
            eval "read -p \"$1${3+ [$3]}: \" $2" || die "(end of file)"
        fi
        eval : "\${$2:=\$3}"
    done
}

yesorno () {
    echo "";
    while :; do
        query "$1" YESORNO y
        case "$YESORNO" in
            Y*|y*) echo; return 0;;
            N*|n*) echo; return 1;;
            *) echo "Please enter 'y' or 'n'" >&2;;
        esac
    done
}

pull_AD(){
  # Pull Unix enabled users from AD
  /opt/quest/libexec/oat/oat_adlookup $VAScreds -o $ADusers user
  /opt/quest/libexec/oat/oat_adlookup $VAScreds -o $ADgroups group
}

match_oat(){
  # Match against entries in the /etc/passwd, utilize usermap.
  /opt/quest/libexec/oat/oat_match -m $Usermap -a $ADusers -x $Passwd user > $OATmatchedUsers
  /opt/quest/libexec/oat/oat_match -a $ADgroups -x $Group group > $OATmatchGroups
}

matched_User_Groups(){
  grep -v "^#" $OATmatchedUsers >> $OATmatchGroups
  #echo "1028(1022223) 10001(unixusr)" >> $FindGroups
}

test_oat(){
  # Run OAT in Test mode
  /opt/quest/libexec/oat/oat_changeowner -r -t process -b $OATBACKUP -u $OATmatchedUsers -d $PROCDIR
  echo "The following OAT map file was processed in Test mode:"
  echo "localUID(local_username) ADuid(ADaccount)"
  cat $OATmatchedUsers
  echo "Processing Groups"
  /opt/quest/libexec/oat/oat_changeowner -r -t process -b $OATBACKUP -g $OATmatchGroups -d $PROCDIR
  echo "================="
  cat $OATmatchGroups
  if yesorno "Show Files to be processed?" yes; then
    less $OATBACKUP/testmode-changes_made_during_process
  fi
  echo "If everything looked sane, go ahead and commit."
  echo "$myname commit"
}

commit_oat(){
  if [ -d $OATBACKUP ]; then
    if yesorno "Overwrite the existing Backup?" yes; then
      /opt/quest/libexec/oat/oat_changeowner -r process -w -m -u $OATmatchedUsers -d $PROCDIR
      /opt/quest/libexec/oat/oat_changeowner -r process -w -g $OATmatchGroups -d $PROCDIR
    else
      # Run OAT in Commit mode (removed -t)
      # -r no run-level check, -m remove users from passwd file, -u matched user file
      /opt/quest/libexec/oat/oat_changeowner -r process -m -u $OATmatchedUsers -d $PROCDIR
      /opt/quest/libexec/oat/oat_changeowner -r process -g $OATmatchGroups -d $PROCDIR
    fi
  fi

}

rollback_oat(){
  # Run OAT in rollback mode
  # This mode will put everything back how it was found originally by OAT
  /opt/quest/libexec/oat/oat_changeowner -r -p rollback -b $OATBACKUP
  # Rollback homedir
  sh -x $HomeRollback
  # Rollback Purged GroupsPurged
  cat $GroupsPurged >> $Group
}

purge_group(){
  # Remove User entries if they exist in /etc/group
  if [ -f "$GroupsPurged" ]; then
    mv $GroupsPurged $GroupsPurged.$Epoch
  fi

  if [ -f "$OATmatchedUsers" ]; then
    for User in `cat $OATmatchedUsers |awk '{print $1}'|awk -F\( '{print $2}'|sed 's/.$//'`; do
      if grep -q ^$User $Group; then
        grep ^$User $Group >> $GroupsPurged
        sed -i "/^$User/d" $Group
      fi
    done
  fi
}

purge_group_test(){
  # Remove User entries if they exist in /etc/group
  if [ -f "$GroupsPurged" ]; then
    mv $GroupsPurged $GroupsPurged.$Epoch
  fi

  if [ -f "$OATmatchedUsers" ]; then
    for User in `cat $OATmatchedUsers |awk '{print $1}'|awk -F\( '{print $2}'|sed 's/.$//'`; do
      if grep -q ^$User $Group; then
        grep ^$User $Group >> $GroupsPurged
        # sed -i "/^$User/d" $Group
      fi
    done
  fi

  echo "The following groups would be purged from system."
  cat $GroupsPurged
}

mod_Homedir(){
  # Occasionally, the home directory name defined in AD will not match the local homedir, this function
  # changes the home directory name to match AD.
  echo "match_Homedir spot"
  for Line in `grep -v "^#" $OATmatchedUsers`; do
    LocalName=`echo $Line|awk '{print $1}'|awk -F\( '{print $2}'|sed 's/.$//'`
    ADname=`echo $Line|awk '{print $1}'|awk -F\( '{print $1}'|sed 's/.$//'`
    if [ "$ADname" = "$LocalName" ]; then
      continue
    else
      if [ -d /home/$LocalName ]; then
        echo "mv /home/$ADname /home/$LocalName" >> $HomeRollback
        mv /home/$LocalName /home/$ADname
      fi
      continue
    fi
  done
}

Main $1
