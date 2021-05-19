# monero-starter
Not really for public use
starts / keeps monerod running and auto updates

# Setup

starter.sh and updater.sh can be ran by the node user, so monerod
uptime.sh needs to be ran by the root user so it can restart services

so you need 2 users on the system
the monerod user for running the node and the root user for restarting tor or rebooting if the node goes offline
setup.sh handles keeping the monerod node itself online and uptime.sh keeps tor online.

I would make a directory names xmrnode in the home directory of the monerod user.
Keep all files in this xmrnode directory and add the following crontabs to the root and monerod users crontab.



# REQUIRES updater.sh / monero-installer script for auto updating
Put this script in the same dir as this script also make sure top vars are correct
