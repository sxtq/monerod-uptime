# monero-starter
Not really for public use.
The scripts here will make sure monerod is online and uptodate, they also will make sure tor stays online limiting downtime. 
The scripts will restart tor and reboot the server if needed. You should follow my recommended setup but it can be ran however you want just make sure you edit all the variables in the scripts to match your setup.

# Recommended Setup
This was created on debian so stick to ubuntu based distros or you will need to modify the script

NOTE: This requires the following dependencies
```
sudo apt install tmux wget gnupg curl
```
1. Create a new user named monerod. (This user should not be sudo)
2. Move the xmrnode directory to the monerod users home directory and make sure monerod user owns all the files
3. Edit the startup.sh and uptime.sh script with the correct api key for pushover and correct sites with ports in the vars (Also edit other vars if needed)
4. Create .bitmonero directory in the home directory of the monerod user, then add the given config file inside the .bitmonero directory (bitmonero.conf)
5. Add the first crontab to the Monerod users crontabs
6. Add the second crontab to the root users crontabs 

Monerod users crontab:
```
* * * * * /home/monerod/xmrnode/starter.sh >/dev/null 2>&1
```
Root users crontab:
```
* * * * * flock -n /home/monerod/xmrnode/active.tmp /home/monerod/xmrnode/uptime.sh >/dev/null 2>&1
```
