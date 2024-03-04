#!/bin/bash

DEPLOY_ENV_OPTIONS=("staging" "production")
GIT_BRANCH="main"
COMMIT_MESSAGE="Updates - $(date +"%Y-%m-%d %T")"
SSH_USER="example"
SSH_SERVER="XXX.XXX.XX.XX"
SSH_PORT="22"
SSH_WORK_PATH="/home/example/laravel"










# Arrow key menu functions - copied from https://unix.stackexchange.com/questions/146570/arrow-key-menu

function select_option {
  ESC=$( printf "\033")
  cursor_blink_on()  { printf "$ESC[?25h"; }
  cursor_blink_off() { printf "$ESC[?25l"; }
  cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
  print_option()     { printf "   $1 "; }
  print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
  key_input()        { read -s -n3 key 2>/dev/null >&2
                        if [[ $key = $ESC[A ]]; then echo up;    fi
                        if [[ $key = $ESC[B ]]; then echo down;  fi
                        if [[ $key = ""     ]]; then echo enter; fi; }

  for opt; do printf "\n"; done

  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - $#))

  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  local selected=0
  while true; do
    local idx=0
    for opt; do
      cursor_to $(($startrow + $idx))
      if [ $idx -eq $selected ]; then
        print_selected "$opt"
      else
        print_option "$opt"
      fi
      ((idx++))
    done

    case `key_input` in
      enter) break;;
      up)    ((selected--));
        if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
      down)  ((selected++));
        if [ $selected -ge $# ]; then selected=0; fi;;
    esac
  done

  cursor_to $lastrow
  printf "\n"
  cursor_blink_on

  return $selected
}


function select_opt {
  select_option "$@" 1>&2
  local result=$?
  echo $result
  return $result
}




#### THE ACTUAL DEPLOY SCRIPT ####




## Build FE assets
npm run build


## Add new files to repo
git add --all


## Prompt for commit message (and provide a default)
echo "Enter Git commit message (default: $COMMIT_MESSAGE)"
read NEW_MESSAGE
[ -n "$NEW_MESSAGE" ] && COMMIT_MESSAGE=$NEW_MESSAGE
git commit -am "$COMMIT_MESSAGE"


## Push to origin branch
git push origin $GIT_BRANCH


## Prompt for deployment target
echo ""
echo ""
echo "Deploy to:"


## Trigger deployment on remote

case `select_opt "${DEPLOY_ENV_OPTIONS[@]}"` in
  *) ssh $SSH_USER@$SSH_SERVER -p $SSH_PORT -t ". $SSH_WORK_PATH/deploy-remote.sh -e ${DEPLOY_ENV_OPTIONS[$?]}";;
esac


exit
