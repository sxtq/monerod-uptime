#!/bin/bash

#Set TOKEN = Token give to you when you setup the bot
TOKEN=
#Set CHAT_ID = To your chat id with the bot
CHAT_ID=
#Onion site to monitor. Set port like example.
site=
#Clear net or local site to monitor. Set port like example.
site2=
#Main directory for uptime.sh and status.log. This is also the directory xmr (Monerod files) will be put inside.
dir=/home/monerod/xmrnode
#The location of the .bitmonero file where the config file and blockchain are stored
datadir=/home/monerod/.bitmonero
#The directory monerod is inside so /root/xmrnode/xmr/monerod. Recommended to leave as is.
wd="$dir"/xmr
#The location of the log file. Recommended to leave as is.
log="$dir"/status.log
log2=/home/six/status.log
#RPC port
rpcport=18087
#Enable or disable rescue (reboot and systemctl restart) function 1 = ON 0 = OFF
rescuef=1
#do you want to use tor?
tor=1
#do you wanna check over clear
clear=1
#Day that the script will run the reset function
resetday=10

YELLOW='\033[1;33m'
NC='\033[0m'

alert () {
  echo -e "${YELLOW}$msg${NC}"
  echo "$(date) / $msg" >> "$log"
  echo "$(date) / $msg" >> "$log2"
  if [ "$snd" = "1" ] ; then
    curl -s -X POST https://api.telegram.org/bot"$TOKEN"/sendMessage -d chat_id="$CHAT_ID" -d text="$msg"
    echo ""
    snd=0
  fi
}

nofreeze () {
  filename="$log"
  b=0
  m1=$(md5sum "$filename")
  if [  -f "$dir"/run.lock ] ; then
    msg="STARTING BACKGROUND FREEZE DETECTION LOOP" && alert
    while [ -f "$dir/active.tmp" ] ; do
      ((b=b+1))
      sleep 1
      if [ "$b" = '600' ] ; then
        m2=$(md5sum "$filename")
        if [ "$m1" = "$m2" ] ; then
          if [  -f "$dir/run.lock" ] ; then
            msg="RUN FILE STILL FOUND NOTHING TO DO" && alert
	    m2=$(md5sum "$filename")
          else
            msg="RUN FILE NOT FOUND BREAKING" && alert
            break
          fi
          msg="THIS SCRIPT IS FROZEN REMOVING LOCK FILE AND KILLING SCRIPT" && snd=1 && alert
          rm "$dir"/active.tmp
          killall uptime.sh
        else
          msg="NOT FROZEN SETTING COUNTER TO 0 AND UPDATING SUM" && alert
          m1=$(md5sum "$filename")
          b=0
          if [  -f "$dir"/run.lock ] ; then
            msg="RUN FILE STILL FOUND NOTHING TO DO" && alert
          else
            msg="RUN FILE NOT FOUND BREAKING" && alert
            break
          fi
        fi
      fi
    done &
  fi
}

reset () {
  day=$(date '+%-d')
  subday=1
  preday=$(("$resetday"-"$subday"))
  if [ "$day" = "$preday" ] && [  -f "$dir"/reset.lock ] ; then
    msg="PRE RESET DAY REMOVING RESET.LOCK FILE" && alert
    rm "$dir"/reset.lock
  else
    msg="NOT PRE RESET DAY OR NO LOCK FILE NOTHING TO DO" && alert
  fi
  if [ "$day" = "$resetday" ] && [ ! -f "$dir"/reset.lock ] ; then
    msg="RESET RUNNING RESET FUNCTION" && alert
#-----------\/reset script here\/-----------

    msg="MONTHLY STATUS REPORT UPTIME: $uptime VERSION: $mversion | SYNC STATUS: $percentage% | IN PEERS: $inpeers | OUT PEERS: $outpeers | DISK USAGE: $used% | UPDATE AVALIBLE: $updateav" && snd=1 && alert

#-----------/\reset script here/\-----------
    rm "$log.old"
    rm "$log2.old"
    mv "$log" "$log.old"
    mv "$log2" "$log2.old"
    touch "$dir"/reset.lock
  else
    msg="NOT RESET DAY OR RESET.LOCK WAS FOUND" && alert
  fi
}

timer () {
  timerloop=1
  h=0
  m=0
  s=0
  d=0
  while [ "$timerloop" = '1' ] ; do
    ((s=s+1))
    sleep 1
    if [ "$s" = '60' ] ; then
      ((m=m+1))
      s=0
    fi
    if [ "$m" = '60' ] ; then
      ((h=h+1))
      m=0
    fi
    if [ "$h" = '24' ] ; then
      ((d=d+1))
      h=0
    fi
    echo "d$d h$h m$m s$s" > "$dir"/downtime.tmp
  done &
}

usage () {
  msg="CHECKING DISK USAGE" && alert
  used=$(df -hl "$wd" | awk '{ sum+=$5 } END { print sum }')
  if [ "$used" -ge 90 ] ; then
    msg="DISK UTILIZATION IS $used% THE SERVER IS RUNNING LOW ON DISK SPACE" && alert
    if [[ ! -e "$dir"/noti.lock ]] && [ "$used" -ge 95 ] ; then
      msg="DISK UTILIZATION IS $used% THE SERVER IS RUNNING LOW ON DISK SPACE" && snd=1 && alert
      touch "$dir"/noti.lock
    else
      msg="DISK USAGE ABOVE 95% BUT CANT SEND NOTIFCATION DUE TO LOCK" && alert
    fi
  else
    msg="DISK UTILIZATION IS: $used%" && alert
    rm "$dir"/noti.lock
  fi
}

sync () {
  msg="STARTING SYNC FUNCTION" && alert
  statput=$("$wd"/monerod --rpc-bind-port "$rpcport" status)
  percentage=$(echo "$statput" | sed -n '1!p' | sed -e 's/.*(\(.*\)%).*/\1/')
  inpeers=$(echo "$statput" | sed -n '1!p' | sed -e 's/.*+\(.*\)(in).*/\1/')
  outpeers=$(echo "$statput" | sed -n '1!p' | sed -e 's/.* \(.*\)(out).*/\1/')
  if echo "$statput" | grep "+0(in)" ; then
    msg="NO INCOMING CONNECTIONS CHECK FIREWALLS/ROUTERS ALLOW PORT 18080" && alert
  fi
  if [ "$percentage" = '100.0' ] ; then
    msg="THE NODE IS SYNCED TO: $percentage%" && alert
    msg="CURRENT IN PEERS: $inpeers" && alert
    msg="CURRENT OUT PEERS: $outpeers" && alert
  else
    if [ "$percentage" = '99.9' ] ; then
      msg="THE NODE IS NOT 100% SYNCED COULD HAVE JUST STARTED OR BE UNDER ATTACK: $percentage%" && alert
      sleep 2m
      percentage=$("$wd"/monerod --rpc-bind-port "$rpcport" status | sed -n '1!p' | sed -e 's/.*(\(.*\)%).*/\1/')
      if [ "$percentage" = '99.9' ] ; then
        msg="THE NODE IS UNDER ATTACK STARTING BAN FUNCTION: $percentage%" && snd=1 && alert
      fi
    else
      rm "$dir"/run.lock
      loop3=2
      while [ "$loop3" -le 2 ] ; do
        if "$wd"/monerod --rpc-bind-port "$rpcport" status | grep 100.0% ; then
          msg="THE NODE REPORTED 100 SYNC CHECKING AGAIN IN 3 MINUTES" && alert
          sleep 10
          if "$wd"/monerod --rpc-bind-port "$rpcport" status | grep 100.0% ; then
             msg="NODE IS NOW 100% SYNCED" && snd=1 && alert
             touch "$dir"/run.lock
             loop3=3
          fi
        else
          status=$("$wd"/monerod --rpc-bind-port "$rpcport" status | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")
          msg="NODE STATUS $status" && snd=1 && alert
          sleep 60m
        fi
      done
    fi
  fi
}

rescue () {
  msg="STARTING RESCUE FUNCTION" && alert
  if [ "$rescuef" = '1' ] ; then
    if [ "$save" = '0' ] ; then
      msg="RESCUE ATTEMPTING TOR REFRESH" && snd=1 && alert
      systemctl restart tor
      sleep 20
      if curl -IL --socks5-hostname 127.0.0.1:9050 http://"$site"/get_info ; then
        msg="RESCUE SUCCSESFUL $site IS ONLINE" && snd=1 && alert
        rm "$dir"/active.tmp
        exit 1
      else
        msg="RESCUE $site IS STILL OFFLINE REBOOTING" && snd=1 && alert
        rm "$dir"/active.tmp
        touch "$dir"/rekey.tmp
        sudo shutdown -r 0
        exit 1
      fi
    fi
    if [ "$save" = '1' ] ; then
      if curl -IL http://"$site2"/get_info ; then
        msg="RESCUE SUCCSESFUL $site IS ONLINE" && snd=1 && alert
        rm "$dir"/active.tmp
        exit 1
      else
        msg="$site2 IS STILL OFFLINE REBOOTING" && snd=1 && alert
	rm "$dir"/active.tmp
	touch "$dir"/rekey.tmp
        sudo shutdown -r 0
	exit 1
      fi
    fi
  else
    msg="RESCUE FUNCTION IS DISABLED" && snd=1 && alert
  fi
}

rekeycheck () {
  if [  -f "$dir"/rekey.tmp ] ; then
    timer
    sleep 2
    rekeyloop=1
    ccheck=1
    tcheck=1
    while [ "$rekeyloop" = "1" ] ; do
      msg="REKEY.TMP FOUND STARTING RECHECK" && alert
      if [ "$tor" = "1" ] ; then
        if curl -IL --socks5-hostname 127.0.0.1:9050 http://"$site"/get_info ; then
          msg="RECHECK TOR GOOD CONNECTION" && alert
          tcheck=1
        else
          msg="RECHECK TOR BAD CONNECTION" && alert
          systemctl restart tor
          tcheck=0
        fi
      fi
      if [ "$clear" = "1" ] ; then
        if curl -IL http://"$site2"/get_info ; then
          msg="RECHECK CLEAR GOOD CONNECTION" && alert
          ccheck=1
        else
          msg="RECHECK CLEAR BAD CONNECTION" && alert
          ccheck=0
        fi
      fi
      if [ "$ccheck" = "1"  ] && [ "$tcheck" = "1" ] ; then
        dt=$(cat "$dir"/downtime.tmp)
        msg="GOOD CONNECTION DOWNTIME: $dt" && snd=1 && alert
        rekeyloop=0
        timerloop=0
        rm "$dir"/rekey.tmp
      else
        dt=$(cat "$dir"/downtime.tmp)
        msg="RECHECK OFFLINE CHECKING AGAIN IN 3 MINUTE DOWNTIME: $dt" && snd=1 && alert
        sleep 3m
      fi
    done
  fi
}

sitecheck () {
  if [ "$tor" = "1" ] ; then
    msg="CHECKING THE CONNECTION TO $site" && alert
    if curl -IL --socks5-hostname 127.0.0.1:9050 http://"$site"/get_info ; then
      msg="GOOD CONNECTION TO $site" && alert
    else
      msg="FAILED BAD CONNECTION TO $site" && alert
      sleep 2m
      if curl -IL --socks5-hostname 127.0.0.1:9050 http://"$site"/get_info ; then
        msg="RERUN GOOD CONNECTION TO $site" && alert
      else
        msg="RERUN BAD CONNECTION TO $site" && snd=1 && alert
        save=0
        rescue
      fi
    fi
  fi
  if [ "$clear" = "1" ] ; then
    msg="CHECKING THE CONNECTION TO $site2" && alert
    if curl -IL http://"$site2"/get_info ; then
      msg="GOOD CONNECTION TO $site2" && alert
    else
      msg="FAILED BAD CONNECTION TO $site2" && alert
      sleep 2m
      if curl -IL http://"$site2"/get_info ; then
        msg="RERUN CONNECTION GOOD TO $site2" && alert
      else
        msg="RERUN BAD CONNECTION TO $site2" && snd=1 && alert
        save=1
        rescue
      fi
    fi
  fi
}

touch "$dir"/active.tmp
mkdir "$dir"
clear
msg="CURRENT UPTIME: $(uptime)" && alert
nofreeze

rekeycheck
sitecheck
sync
usage
reset

rm "$dir"/active.tmp
sleep 1
echo "---------------------------------------------------------------------------------" >> "$log"
echo "---------------------------------------------------------------------------------" >> "$log2"
