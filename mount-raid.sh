#! /bin/bash

LOG=/var/log/mount-raid.log
RAID=/dev/md1

function log()  {
  message=`date`
  message+=" ["
  message+=$1

  shift

  message+="] - "
  message+=$@

  echo $message >> $LOG 
}

function error()  {
  log "ERROR" $@
}

function fatal()  {
  log "FATAL" $@
}

function info()  {
  log "INFO" $@
}

function die()  {
  fatal "Can't continue, exiting because: " $@
  exit 1
}

function checkDrives()  {
  declare -a driveLetters=('a' 'b' 'c');

  for ((i=0; i < ${#driveLetters[@]}; i++)) ; do
    letter=${driveLetters[$i]}
    count=`ls /dev | grep -c "sd${letter}1"`

    if [ $count -lt 1 ] ; then
      error "/dev/sd${letter} appears to be missing"
      die "Needed drive is missing"
    fi
  done
}

function assemble()  {
  checkDrives

  # is the RAID already running?
  mdadm -D $RAID > /dev/null
  
  if [ $? -gt 0 ] ; then
    info "Attempting to assemble $RAID"
  
    log=`mdadm --assemble $RAID 2>&1`
    result=$?
 
    info $log
 
    if [ $result -ne 0 ] ; then
      error "Status code is not 0 ($result); check /proc/mdstat"
    else
      mdadm -G $RAID -b none
      mdadm -G $RAID -b internal
    fi
  else
    info "RAID already assembled"
    
    mdadm -G $RAID -b none
    mdadm -G $RAID -b internal
  fi
}

function unassemble()  {
  # is the RAID already running?
  mdadm -D $RAID > /dev/null
  
  if [ $? -eq 0 ] ; then
    info "Attempting to stop $RAID"
 
    umount /mnt/media 
    log=`mdadm --stop $RAID 2>&1`
    result=$?
 
    info $log
 
    if [ $result -ne 0 ] ; then
      error "Status code is not 0 ($result); check /proc/mdstat"
    fi
  else
    info "RAID not assembled"
  fi
}

while getopts ":u" opt; do
  case $opt in
    u)
      unassemble
      exit
      ;;
  esac
done

assemble

# Note: RaspBMC automounts based off /etc/fstab
#       If mounting fails, you can still do it manually.
