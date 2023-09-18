## setup autorestic to take postgres db backup up to backblaze

## Home directory of the user

- .autorestic.env 
- .autorestic.yml
- *.sh

Note: find and replace the home directory path in all above files

 ### crontab
```bash
PATH="/usr/local/bin:/usr/bin:/bin"

*/5 * * * * autorestic -c /home/worker/.autorestic.yml --ci cron > /home/worker/autorestic.log 2>&1
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
