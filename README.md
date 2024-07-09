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
# m h  dom mon dow   command
PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin"
MAILTO=""

# Auto restic run every 10 min, logs to a files, file rotates daily and summary sent daily
0 0 * * * . /home/pi/.profile; /backup_scripts/autorestic_email_log_summary.sh /home/pi/autorestic.log/$(date -d 'yesterday' +\%Y\%m\%d)-cron.log 2>&1
*/10 * * * * autorestic -c /home/pi/.autorestic.yml --ci -v cron >> /home/pi/autorestic.log/`date +\%Y\%m\%d`-cron.log &2>1
0 0 * * * /backup_scripts/keep_upto.sh -d /home/pi/autorestic.log/ -e .log -k 7 --skip-safe-check &2>1

# timelapse photos sync from phone to NAS using adb
10 */6 * * * /backup_scripts/dadb.sh -p 192.168.1.53 -a 38025 -r /sdcard/DCIM/OpenCamera -l /mnt/ssd-4tb/timelapse/ -f *.jpg -c >> /mnt/ssd-4tb/timelapse/log/`date +\%Y\%m\%d`-cron.log  &2>1
0 0 * * * /backup_scripts/keep_upto.sh -d /mnt/ssd-4tb/timelapse/log/ -e .log -k 7 --skip-safe-check &2>1
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

