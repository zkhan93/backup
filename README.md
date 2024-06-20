## Personal Backup Solution

This is a personal backup solution using [autorestic](http://autorestic.vercel.app/) and [restic](https://restic.readthedocs.io/en/latest/). The backup is stored in [backblaze](https://www.backblaze.com/).

### Tasks
- [x] Setup autorestic
- [x] Setup ssmtp
- [x] Setup crontab


## required files and directories

create the following files in the home directory of the user

- ~/.autorestic.env - contains the environment variables for autorestic
- ~/.autorestic.yml - contains the configuration for autorestic
- ~/autorestic.log - directory to store the logs
- /backup_scripts - directory to store the backup scripts

 ### crontab
```bash
PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin"
MAILTO=""

0 0 * * * /backup_scripts/keep_upto.sh -d /home/pi/autorestic.log/ -e .log -k 7 --skip-safe-check
0 5 * * *  /backup_scripts/autorestic_email_log_summary.sh /home/pi/autorestic.log/`date +\%Y\%m\%d`-cron.log
*/10 * * * * autorestic -c /home/pi/.autorestic.yml --ci -v cron >> /home/pi/autorestic.log/`date +\%Y\%m\%d`-cron.log &2>1
```

#### SSMTP 
install ssmtp and setup config

```
#
# Config file for sSMTP sendmail
#
# The person who gets all mail for userids < 1000
# Make this empty to disable rewriting.
root=

# The place where the mail goes. The actual machine name is required no
# MX records are consulted. Commonly mailhosts are named mail.domain.com
mailhub=smtp.gmail.com:465

# Where will the mail seem to come from?
#rewriteDomain=


# The full hostname
hostname=

# Are users allowed to set their own From: address?
# YES - Allow the user to specify their own From: address
# NO - Use the system generated From: address
FromLineOverride=NO


AuthUser=
AuthPass=
UseTLS=YES
```
## References
- [autorestic](http://autorestic.vercel.app/)
- [restic](https://restic.readthedocs.io/en/latest/)
- [backblaze](https://www.backblaze.com/)
- [ssmtp](https://wiki.archlinux.org/title/SSMTP)
- [crontab](https://crontab.guru/)

