# backupcdm
Simple shell script for backup using restic backend

Long story short, I use this for my server just to simplify (and a little bit complicating) the backup procedure.
It is using restic as the backend.

COMPATIBILITY
- Linux; All distribution should be fine as long as bash and restic can run. I tested it in some SLES, Centos, Debian, and Ubuntu (with several different releases).
- Database dump support: mysql, postgresql, mssql, and mongodb. Not tested the version one by one but as long as the dump options are correct everything will be okay.
- Tested it with restic > 0.10.0. Not tested on version before that.
- It is run on root.

HOW TO USE
- Create a folder, put the backup.sh and conf folder with all it's content on that very same folder. Make the backup.sh executable.
- Create or copy conf/sample.conf to conf/conf.conf and configure it with your liking
- Install restic or copy the binary restic and place it on the path configured in conf.conf. Don't forget to make it executable.
- If you are backing up files other than database, create a include file (conf/include.txt) and fill it with path to be backed up.
- If you are backing up databases, create a dbinclude file (conf/dbinclude.txt) and fill it with database list to be backed up.
- Run the backup.sh or insert it into cron
- Check everyday the log just in case something wrong happened

TODO
- Restructure script for better error-handling (catching which line caused the script crash) and better notifier of course
- Create an installer and auto check all the dependency for easier and more secure deployment
- Create a man file or wiki for better documentation and explanation
- Add timeout when dumping database, just in case the database cannot be dumped.
- Make script not doing the same things in case the server hanged or rebooted while backing up
- Add checker for the host storage, so the host will not be running out of storage when backing up
- Test and rework the script so it will work on all user (not only root)
- Add support for mounting external storage and unmount them (so there is no need for remote storage to be always mounted)
- Central configuration, log, and back up progress for several hosts in a single dashboard (a huge goal, to make this kinda web based!)
- etc
