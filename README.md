# breadsMCtools

A small collection (for now) of things I use on my minecraft server. 
- ```backup.sh``` A pretty simple script to backup your entire LINUX Minecraft Server directory to another directory of your choice. It can also auto-update to the latest version of Paper (github.com/PaperMC/Paper) after 'x' number of days. It has some error checking, logs everything it does, auto-deletes old backups after 'x' days and has the ability to alert using Pushover (www.pushover.net).
- ```minecraft-server.service``` - A Linux service file to run your PaperMC server in a screen session

## Why and Getting Started

Hopefully you'll find this script of some use, this all started when my personal server crashed and I lost everything. It started on a windows machine with a batch file backup job to a NAS, then to powershell script because I didn't like .bat logging, and now to a full blown ESXi VM with nightly backups and automated updates.

### Prerequisites

This script is based on my server which uses the following:

- Linux server (Debian 9 or Ubuntu) already running a [PaperMC](https://github.com/PaperMC/Paper) server
- Server running via a service: [minecraft-server.server](./minecraft-server.service)
- Server running in Linux [screen](https://linux.die.net/man/1/screen)
- Permissions to start/stop the service without a password prompt (lookup [sudoers](https://linux.die.net/man/5/sudoers))
```
"username" ALL=NOPASSWD:/usr/sbin/service "service file name" start
"username" ALL=NOPASSWD:/usr/sbin/service "service file name" stop

minecraft ALL=NOPASSWD:/usr/sbin/service minecraft-server stop
minecraft ALL=NOPASSWD:/usr/sbin/service minecraft-server start
```
- (Temporary) A pushover account from pushover.net (hoping to remove this Dependency soon), in the meantime you can comment out any "push" code in there


### Mandatory items
A few variables must match exactly in your service file and the [backup.sh](./backup.sh) script.

1. If your service file name is *"minecraft-server.service"* then the _**servicename**_ variable in the [backup.sh](./backup.sh) script will be ```servicename="minecraft-server"```
2. In your service file, the name of the screen in this command for example ```ExecStart=/usr/bin/screen -h 2048 -dmS SCREENNAME java ``` must match the screenname variable in the [backup.sh](./backup.sh) script. Using this as an example your [backup.sh](./backup.sh) script _**screenname**_ variable will be ```screenname=SCREENNAME```
3. _**source**_ = the directory to be backed up (ex: /somedir/minecraft)
4. _**dest**_ = where the archive files will be placed (ex: /mnt/someNASdevice/minecraftbackup)
5. _**savemethod**_ = 'y' or 'n'
- This determines if the script will send a _stop-save_ command (the __'y'__ option) to the server or a _stop_ (the __'n'__ option) to the server
  - Note if you want the server to auto upgrade this variable must be set to __'n'__
6. If you plan on using the automatic update part, create a directory in your _**source**_ folder called .jarbackups
   - ``` mkdir .jarbackups/ ```
   - This is a hidden folder the old paperclip.jar files live in for x (30 by default) days before being automatically deleted

### Optional items

1. _**daystokeep**_ = how many days to keep backup files in the $dest (default "+7")
    - Note that the + sign needs to be in front, same goes for the variables below except "tries"
2. _**paperclipupdateinterval**_ = how many days old the paperclip.jar file needs to be before it's updated (default is "+5")
3. _**paperclipjartime**_ = how many days to keep the old replaced paperclip.jar files in the .jarbackups folder before deleting them (default is +30)
4. _**tries**_ = this probably isn't needed anymore, description in script.
5. _**log_file**_ = what the logfile is called and where it's stored (default $dest"log.txt")
6. _**autoupdate**_ = if you want your paperclip.jar file to automatically update after _**paperclipupdateinterval**_ days

### Pushover variables
1. _**pushtoken**_ = Your pushover API key
2. _**pushuser**_ = Your pushover user key
3. _**pushsubject**_ = Subject of the push (Minecraft server alert)

## Screenshots
![pushover](http://badbread.com/wp-content/uploads/2018/08/breadsMCtools_push.jpg)

## Built With

* BASH

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

* **badbread** - *Initial work* - [badbread](https://github.com/badbread)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

[Mike Buss](https://github.com/mikebuss) for the super simple pushover function [here](https://mikebuss.com/2014/01/03/push-notifications-cli/)

