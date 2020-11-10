# backupcdm
Simple shell script for backup using restic backend

Long story short, I use this for my server just to simplify (and a little bit complicating) the backup procedure.
It is using restic for now as the backend, but maybe in the future I will create for other backend (like maybe borgbackup, rdiff, rsync, etc)

HOW TO USE
- Create a folder, put the backup.sh and conf.conf in that same folder
- Set the variable on conf.conf suited for your environment
- Download the binary restic, copy it into the same folder as backup.sh and conf.conf and rename the restic binary file into restic
- Create a include file (suit the name as in the conf.conf) that listed all file and folders to backup separated by enter
- Change the backup.sh and restic into executable (chmod)
- run the backup.sh or insert it into cron

TODO
There are a lot to do, but most important things:
- Add support for other databases (example: postgresql)
- Add try and catch for error on dumping the database and when backing up using restic
- Simplify the script using function
- Forbid script to run twice or more (in case it stuck)
- Make script recoverable in case the server hanged or rebooted (not doing things already done twice)
- Auto create the folder needed and the file needed
- Default value for all the variables
