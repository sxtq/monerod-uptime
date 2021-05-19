# monero-starter
Not really for public use
The scripts here will make sure monerod is online and uptodate, they also will make sure tor stays online limiting downtime. 
The scripts will restart tor and reboot the server if needed.

# Setup
starter.sh and updater.sh can be ran by the node user, so monerod
uptime.sh needs to be ran by the root user so it can restart services

so you need 2 users on the system
the monerod user for running the node and the root user for restarting tor or rebooting if the node goes offline
setup.sh handles keeping the monerod node itself online and uptime.sh keeps tor online.

I would move xmrnode to the home directory of the monerod user path: /home/monerod/xmrnode.
Keep all files in this xmrnode directory and add the following crontabs to the root and monerod users crontab.

Monerod users crontab:
```
* * * * * /home/monerod/xmrnode/starter.sh >/dev/null 2>&1
```
Root users crontab:
```
* * * * * flock -n /home/monerod/xmrnode/active.tmp /home/monerod/xmrnode/uptime.sh >/dev/null 2>&1
```
