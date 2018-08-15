#!/bin/bash
# This script assumes you have the following: A Paper (www.github.com/PaperMC/Paper)
# Minecraft Linux server running in a screen installed as a service
# The user running this script needs permissions to start/stop the Minecraft Server
# service using sudo without a password prompt (lookup sudoers on google)
PATH=/opt/minecraft/ #set this to the path you save this file in

###### Mandatory fields, fill this all in ####################################
source="" #directory to be archived ex: /opt/minecraft/
dest="" #destination for archive ex: /mnt/mcLinuxBackup/
savemethod="y"  # savemethod does not stop/start the server, sends a "save-off" command
                # to the server
servicename="" # ex: minecraft-server must match the name of your Minecraft server service
screensession="" #name of your screen session that the service launches
# Make a directory in /minecraft folder called ".jarbackups" it's a hidden folder
# to place a backup of your old paperclip.jar file

##### Options ################################################################
daystokeep="+7" #how many days to keep BACKUP files, must have + sign before number for next 3
paperupdateinterval="+5" #how many days old the paperclip.jar file needs to be to be upgraded
paperclipjartime="+30" #how many days to keep old paperclip.jar files
tries="10" #how long to wait for server to close before giving up "value = *2"

###### Pushover variables ####################################################
pushtoken=""
pushuser=""
pushsubject=""

###### Other variables shouldn't need to be changed #########################
day=$(date +%m%d%Y)
archiveend="_MCBackup.bz2" #part of the archive file name
archivename=$day$archiveend #archive file name
fullarchivename=$dest$archivename #full archive file path
jarbackups=$source.jarbackups/
yesterday=$(date +%m%d%Y -d 'yesterday') #for old .jar file deletion and rename
log_file=$dest"log.txt" #place the log file where the backup files go

###### utility functions ####################################################

# log function, echo's into console automatically
# syntax: log "YOUR MESSAGE HERE" [options]
# Arguments are WARN & ERROR. INFO is passed by default with no argument
log () {
  if [ -z "$2" ]
    then
      echo "$(date +"%Y%m%d-%T") INFO $1"  | tee -a $log_file
  elif [ $2 = "WARNING" ]
     then
      echo "$(date +"%Y%m%d-%T") WARNING $1" | tee -a $log_file
  elif [ $2 = "ERROR" ]
    then
      echo "$(date +"%Y%m%d-%T") ERROR $1" | tee -a $log_file
  else
      echo "$(date +"%Y%m%d-%T") UNKNOWN $1" | tee -a $log_file
  fi
}

#time how long the archive takes
timethis () {
  start=`date +%s`
  $1
  end=`date +%s`
  runtime=$((end-start))
  return
}

#send notification to pushover
push () {
    curl -s -F "token=$pushtoken" \
    -F "user=$pushuser" \
    -F "title=$pushsubject" \
    -F "message=$1" https://api.pushover.net/1/messages.json
    return
}

###### Where the good stuff happens ########################################

#Step 1, shutdown server gracefully or send save-stop command to screen
stopserver () {
  if screen -list | grep -q $screensession
    then
      log "Minecraft server is running"
        if [ $savemethod = "y" ]
          then
            log "Sending the save-off command to server"
            screen -S mcserver -X eval 'stuff "say Server save in progress, might be laggy for a bit"\\015'
            screen -S mcserver -X eval 'stuff "save-off"\\015'
            log "Save-off command sent to MC, moving to create_archive"
            create_archive
          elif [ $savemethod = "n" ]
            then
              log "Minecraft server is running, stopping the $servicename service"
              screen -S mcserver -X eval 'stuff "say Server going down in 5 seconds for backup, check back in a few minutes"\\015'
              sleep 5
              sudo service $servicename stop
                #if for some reason the service doesn't stop the below should stop the loop
                while screen -list | grep -q $screensession && [ $count -le $tries]
                  do
                    count=$((count+1))
                    sleep 2
                    log "Waiting for screen session to close down, attempt $count (max tries is $tries)"
                  done
                create_archive
              else
                log "Please enter y or n in the $savemethod variable" ERROR
                quit
              fi
    else
         log "Minecraft server is NOT running, continuing to create_archive" WARNING
         create_archive
  fi
}

#Step 2, create a compressed archive of the game directory
create_archive () {
  if [ -e $fullarchivename ]
    then
      log "Archive already exists $fullarchivename! Stopping backup!" ERROR
      push "ERROR backing up Minecraft, restarting server, check the logs!! "
      sudo service $servicename start
      exit
    else
      log "Creating archive of directory"
      timethis "tar cfj $fullarchivename $source"
      log "Archive created and uploaded in $runtime seconds, going to delete old backups"
      screen -S mcserver -X eval 'stuff "say Archive done in '$runtime' seconds, back to normal"\\015'
      deloldbackups
  fi
}

#Step 3, delete files in the backup dir older than $daystokeep variable
deloldbackups () {
  log "Looking for backups on $dest older than $daystokeep days"
  if [ -f $dest ]
  #maybe deleteif find $dest -type f -mtime $daystokeep
    then
      while read fname; do
        log "Deleted $fname"
        rm "$fname"
        done
    else
      log "No old backup files to delete"
  fi

  if [[ $(find "$jarbackups" -type f -mtime "$paperclipjartime") ]]
    then
      log "Deleting paperclip.jar files older than $paperclipjartime days"
      find $jarbackups -name 'paperclip*' -type f -mtime $paperclipjartime | while read fname; do
        log "Deleting $fname"
        rm "$fname"
        updateserver
      done
    else
      log "No old paperclip.jar files to delete"
    updateserver
    #add autoupdate if condition here
  fi
}

#Step 4a, check if an X old version of paperclip exists, if it does, rename it, move it to a backup folder
#, and download the new paperclip.jar file from the build server
updateserver () {
  if [ $savemethod = "y" ]
    then
      log "To use the updateserver function you must choose 'n' for the savemethod variable"
      startserver
  elif [ $savemethod = "n" ]
    then
      lastpaper=$(date +%m%d%Y -r $source/paperclip.jar)
      log "The paperclip.jar file was last modded on $lastpaper"
      log "Looking for a paperclip.jar file older than $paperupdateinterval days old"
      if [[ $(find "$source""paperclip.jar" -mtime $paperupdateinterval) ]]
        then
          log "FOUND old paperclip.jar, renaming it to paperclip.$day and moving to $jarbackups folder"
          mv $source/paperclip.jar $jarbackups/paperclip.$day
          log "Downloading latest build of paperclip.jar"
          wget -q -nd https://destroystokyo.com/ci/job/Paper-1.13/lastStableBuild/artifact/paperclip.jar -O $source/paperclip.jar
          log "Download finished"
          startserver
        else
          log "No old paperclip found or it hasn't been $paperupdateinterval days yet, not auto-updating... Starting server"
          startserver
      fi
    else
      log "I should hopefully never see this error because if it's here, then something is really messed up" ERROR
    fi
}

#Step 4b, start the $servicename service, send a push that it completed successfully
startserver () {
  if [ $savemethod = "y" ]
    then
      log "Sending Save-on command to server"
      screen -S mcserver -X eval 'stuff "save-on"\\015'
      screen -S mcserver -X eval 'stuff "say Backup has completed!!"\\015'
      log "Save-on command sent to MC, BACKUP COMPLETE in $runtime2 seconds! ****************************"
      push "Backup completed, all good."
      quit
  elif [ $savemethod = "n" ]
  then
    log "Backup has been completed, BACKUP COMPLETE in $runtime2 seconds!! ******************************"
    sudo service $servicename start
    push "Backup completed, all good."
  fi
}


#start of the log file and backup process
start2=`date +%s`
log "+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
log "Backup started"
stopserver
