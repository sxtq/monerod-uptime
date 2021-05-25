#!/bin/bash

dir=/home/monerod/xmrnode
monerod_dir="$dir"/xmr
backup_monerod_dir="$dir"/xmr.bk
blockchain_dir=/home/monerod/.bitmonero
log="$dir"/starter.log
rpcport=18087

APP_TOKEN=""
USER_TOKEN=""
URL="https://api.pushover.net/1/messages.json"

send () {
  date=$(date)
  wget "$URL" --post-data="token=$APP_TOKEN&user=$USER_TOKEN&message=$2 $date&title=$1&sound=pushover" -qO- > /dev/null 2>&1 &
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

verifyupdate () {
  print "Starting monerod after update" yellow
  tmux new-session -d "$monerod_dir"/monerod --data-dir="$blockchain_dir"
  sleep 10
  if "$monerod_dir"/monerod --rpc-bind-port "$rpcport" status | grep -q "on mainnet"; then
    print "Monerod started and is responding after update" green
    send "XMR Node" "Monerod started and is responding after update"
  else
    print "Monerod failed to start after the update running on backup" red
    send "XMR Node" "Monerod failed to start after the update running on backup"
    rm -dr "$monerod_dir"
    cp -r "$backup_monerod_dir" "$monerod_dir"
    touch "$dir"/update.fail
    tmux new-session -d "$monerod_dir"/monerod --data-dir="$blockchain_dir"
    sleep 10
    if "$monerod_dir"/monerod --rpc-bind-port "$rpcport" status | grep -q "on mainnet"; then
      print "Monerod backup is running, issue needs to be resolved manually" yellow
      send "XMR Node" "Monerod backup is running, issue needs to be resolved manually"
    else
      print "Monerod backup failed to start, issue needs to be resolved manually"
      send "XMR Node" "Monerod backup failed to start, issue needs to be resolved manually"
    fi
  fi

}

checkupdate () {
  rm "$dir"/version
  "$monerod_dir"/monerod --rpc-bind-port "$rpcport" version >> "$dir"/version
  mversion=$(sed -r "s/\x1B\[(([0-9]{1,2})?(;)?([0-9]{1,2})?)?[m,K,H,f,J]//g" "$dir"/version | sed -n '1!p')
  print "Checking for update" yellow
  if "$monerod_dir"/monerod --rpc-bind-port "$rpcport" update check | grep "Update available" || [ -f "$dir"/force.tmp ]; then
    if [ ! -f "$dir"/update.fail ]; then
      print "Update available, current version: $mversion" yellow
      send "XMR Node" "Monerod update available, starting update"
      "$monerod_dir"/monerod exit
      sleep 5
      "$dir"/updater.sh -s
      verifyupdate
    else
      print "Update previously failed so manually removing update.fail file is required"
    fi
  else
    print "No update available" green
  fi
}

starter () {
  print "Checking if monerod is running" yellow
  if "$monerod_dir"/monerod --rpc-bind-port "$rpcport" status | grep -q "on mainnet"; then
    uptime=$("$monerod_dir"/monerod --rpc-bind-port "$rpcport" status | sed -n '1!p' | sed -e 's/.*uptime \(.*\).*/\1/')
    print "Monerod is running, uptime: $uptime" green
  else
    print "Monerod is not running starting now" yellow
    tmux new-session -d "$monerod_dir"/monerod --data-dir="$blockchain_dir"
    sleep 10
    if "$monerod_dir"/monerod --rpc-bind-port "$rpcport" status | grep -q "on mainnet"; then
      print "Monerod started and is responding" green
    else
      rm "$dir"/crash.txt
      "$monerod_dir"/monerod --data-dir="$datadir" --detach >> "$dir"/crash.txt
      crashfile=$(sed -r "s/\x1B\[(([0-9]{1,2})?(;)?([0-9]{1,2})?)?[m,K,H,f,J]//g" "$dir"/crash.txt)
      print "Monerod failed to start crashfile: $crashfile" red
      send "XMR Node" "Monerod failed to start crashfile: $crashfile"
      loop3=2
      while [ "$loop3" -le 2 ] ; do
        print "Rechcking trying to start monerod" yellow
        tmux new-session -d "$monerod_dir"/monerod --data-dir="$datadir"
        sleep 5
        if "$monerod_dir"/monerod --rpc-bind-port "$rpcport" status | grep -q "on mainnet"; then
          print "Recheck monerod started and is responding" green
          send "XMR Node" "Recheck monerod started and is responding"
          loop3=3
        else
          print "Recheck monerod failed to start checking again in 3 minutes" red
          send "XMR Node" "Recheck monerod failed to start checking again in 3 minutes"
          sleep 3m
        fi
      done
    fi
  fi
}

pid_count=$(pgrep starter.sh | wc -l)
if [ "$pid_count" -gt "2" ]; then
  print "Starter script is already running exiting" yellow
  exit 1
fi

starter
checkupdate
