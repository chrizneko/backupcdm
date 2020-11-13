# backupcdm
Simple shell script for backup using restic backend

Long story short, I use this for my server just to simplify (and a little bit complicating) the backup procedure.
It is using restic for now as the backend, but maybe in the future I will create for other backend (like maybe borgbackup or others)

HOW TO USE
- Create a folder, put the backup.sh and conf.conf in that same folder
- Set the variable on conf.conf suited for your environment
- Download the binary restic, copy it into the same folder as backup.sh and conf.conf and rename the restic binary file into restic
- Create a include file (suit the name as in the conf.conf) that listed all file and folders to backup separated by enter
- Change the backup.sh and restic into executable (chmod)
- run the backup.sh or insert it into cron
- Check everyday the log just in case something wrong happened

TODO
There are a lot to do, but most important things:
- Add support for other databases (example: postgresql)
- Add timeout when dumping database, just in case the database cannot be dumped
- Simplify the script using function
- Make script recoverable in case the server hanged or rebooted (not doing things already done twice)
- Auto create the folder needed and the file needed
- Default value for all the variables
- Rework the script to the best case (example: variable not environment should not be in caps)
- Add dynamic path for restic including restic that is installed
- Recheck the availability of the repo, and maybe auto create if there is no repo
- Check the system storage so will not be running out of storage when dumping the database
- Test and rework the script so it will work on all user (not only root)
- Evaluate again the variables needed or not
- Add support for mounting external storage and unmount them (no need for remote storage to be always mounted)
- Add support for external storage that is not compatible with restic (example: CIFS) like, copying manual the result or something
- Simplify the log
- Central configuration and progress on dashboard (a huge goal, to make this kinda web based!)
- etc
