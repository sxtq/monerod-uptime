#!/bin/bash

dir=/home/monerod/xmrnode
tor_site=
clear_site=
log="$dir"/uptime.log
tor=1
clear=1
run_rescue=1

APP_TOKEN=""
USER_TOKEN=""
URL="https://api.pushover.net/1/messages.json"

send () {
  date=$(date)
  timeout 1m wget "$URL" --post-data="token=$APP_TOKEN&user=$USER_TOKEN&message=$2 $date&title=$1&sound=pushover" -qO- > /dev/null 2>&1 &
}

#Used for printing text on the screen
print () {
  no_color='\033[0m'
  if [ "$2" = "green" ]; then     #Print Green
    color='\033[1;32m'
  elif [ "$2" = "yellow" ]; then  #Print Yellow
    color='\033[1;33m'
  elif [ "$2" = "red" ]; then     #Print Red
    color='\033[1;31m'
  fi
  echo -e "${color}$1${no_color}" #Takes message and color and prints to screen
  echo "$(date) / $1" >> "$log"
}

recheck () {
  if [  -f "$dir"/recheck.tmp ] ; then
    checking_loop=1
    while [ "$checking_loop" = "1" ] ; do
      print "Rechecking after reboot" yellow
      if [ "$tor" = "1" ] ; then
        if timeout 1m curl -IL --socks5-hostname 127.0.0.1:9050 http://"$tor_site"/get_info ; then
          print "Recheck good connection over tor" green
          tcheck=1
        else
          print "Recheck bad connection over tor" red
          systemctl restart tor
          tcheck=0
        fi
      fi
      if [ "$clear" = "1" ] ; then
        if timeout 1m curl -IL http://"$clear_site"/get_info ; then
          print "Recheck good connection over clearnet" green
          ccheck=1
        else
          print "Recheck bad connection over clearnet" red
          ccheck=0
        fi
      fi
      if [ "$ccheck" = "1"  ] && [ "$tcheck" = "1" ] ; then
        print "Recheck good connection" green
        send "XMR Node" "Recheck good connection"
        checking_loop=0
        rm "$dir"/recheck.tmp
      else
        print "Recheck bad connection checking again in 3 minutes" red
        send "XMR Node" "Recheck bad connection checking again in 3 minutes"
        sleep 3m
      fi
    done
  fi
}

usage () {
  print "Checking disk usage" yellow
  used=$(df -hl "$dir" | awk '{ sum+=$5 } END { print sum }')
  if [ "$used" -ge 90 ] ; then
    send "Disk utilization is $used% The server is running low on disk space" red
    if [[ ! -e "$dir"/noti.lock ]] && [ "$used" -ge 95 ] ; then
      send "XMR Node" "Disk utilization is $used% The server is running low on disk space"
      touch "$dir"/noti.lock
    else
      print "Disk usage is above 95% but cant send notifcation due to lock" red
    fi
  else
    print "Disk utilization is: $used%" yellow
    rm -rf "$dir"/noti.lock || true
  fi
}

rescue () {
  if [ "$tor_check" = "fail" ] && [ "$clear_check" = "fail" ]; then
    print "Rescue rebooting server (1)" yellow
    send "XMR Node" "Rescue rebooting server"
    rm "$dir"/active.tmp
    touch "$dir"/recheck.tmp
    sudo shutdown -r 0
    exit 1
  elif [ "$tor_check" = "fail" ] && [ "$clear_check" = "pass" ]; then
    print "Rescue attempting tor refresh (2)" yellow
    systemctl restart tor
    sleep 20
    if timeout 1m curl -IL --socks5-hostname 127.0.0.1:9050 http://"$tor_site"/get_info ; then
      print "Resuce succsesful tor connection is good" green
      send "XMR Node" "Resuce succsesful tor connection is good"
    else
      print "Resuce bad connection over tor rebooting" red
      send "XMR Node" "Resuce bad connection over tor rebooting"
      rm "$dir"/active.tmp
      touch "$dir"/recheck.tmp
      sudo shutdown -r 0
      exit 1
    fi
  elif [ "$tor_check" = "pass" ] && [ "$clear_check" = "fail" ]; then
    print "Rescue rebooting server (3)" yellow
    send "XMR Node" "Rescue rebooting server"
    rm "$dir"/active.tmp
    touch "$dir"/recheck.tmp
    sudo shutdown -r 0
    exit 1
  fi
}

sitecheck () {
  if [ "$tor" = "1" ] ; then
    print "Checking connection over tor" yellow
    if timeout 1m curl -IL --socks5-hostname 127.0.0.1:9050 http://"$tor_site"/get_info ; then
      print "Good connection over tor" green
      tor_check=pass
    else
      print "Failed bad connection over tor" red
      sleep 2m
      if timeout 1m curl -IL --socks5-hostname 127.0.0.1:9050 http://"$tor_site"/get_info ; then
        print "Rerun good connection over tor" green
        tor_check=pass
      else
        send "XMR Node" "Rerun bad connection over tor"
        print "Rerun bad connection over tor" red
        tor_check=fail
      fi
    fi
  fi
  if [ "$clear" = "1" ] ; then
    print "Checking connection over clearnet" yellow
    if timeout 1m curl -IL http://"$clear_site"/get_info ; then
      print "Good connection over clearnet" green
      clear_check=pass
    else
      print "Failed bad connection over clearnet" red
      sleep 2m
      if timeout 1m curl -IL http://"$clear_site"/get_info ; then
        print "Rerun good connection over clearnet" green
        clear_check=pass
      else
        send "XMR Node" "Rerun bad connection over clearnet"
        print "Rerun bad connection over clearnet" red
        clear_check=fail
      fi
    fi
  fi
  if [ "$tor_check" = "fail" ] || [ "$clear_check" = "fail" ]; then
    print "     Tor connection status : $tor_check" yellow
    print "Clearnet connection status : $clear_check" yellow
    rescue
  fi
}

pid_count=$(pgrep uptime.sh | wc -l)
if [ "$pid_count" -gt "2" ]; then
  print "Uptime script is already running exiting" yellow
  exit 1
fi

recheck
sitecheck
usage
