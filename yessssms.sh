#!/bin/bash
# Fill out your Yesss Number and password.
# Send SMS from your prepaid SIM via the web.
# $ ./yessssms.sh 0043681123456789 "your message in quotes"
# or
# $ echo "message" | ./yessssms.sh 0043681123456789 -
# ... to read from stdin
# that's it

# NOTE: this script does NOT validate your balance.
# last tested on: 2017-09-12

yesss_number="0681XXXXXXXXXX"
yesss_pw="YOUR_SECRET_YESSS_WEBLOGIN"
#source login_data.sh

#UA="Mozilla/5.0 (Windows; U; Windows NT 6.1; de; rv:1.9.1.4) Gecko/20091017 SeaMonkey/2.0"
UA="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.12) Gecko/20101026 Firefox/3.6.12"
KMURL="https://www.yesss.at/kontomanager.at/kundendaten.php"

num=$1
RES1=`curl -s -i -A "$UA" -d "login_rufnummer=$yesss_number&login_passwort=$yesss_pw" https://www.yesss.at/kontomanager.at/index.php`
SESSID=`echo $RES1 | grep Set-Cookie | grep PHPSESSID | sed 's/.*\(PHPSESSID=[^;]*\);.*/\1/g'`
#echo $SESSID
#BAL=`curl -s -A "$UA" -b "$SESSID" $KMURL | grep -A 2 -i Guthaben |  grep -i EUR | sed 's/.*\(EUR [0-9]*[\.,][0-9]*\).*/\1/g'` 
balance_html=`curl -s -A "$UA" -b "$SESSID" $KMURL`
BAL=`echo $balance_html |sed 's/<\/div>/<\/div>\n/g'| grep -A 5 -i -e 'Minuten/SMS' -e 'Min/SMS/MB' |  grep -i Verbleibend | sed 's/.*\(Verbleibend: [0-9]*[\.,]*[0-9]*\).*/\1/g'`

GUT=`echo $balance_html | grep -A 2 -i "Ihr aktuelles Standardguthaben" | grep -i "EUR"| sed 's/.*\(EUR [0-9]*[\.,]*[0-9]*\).*/\1/g'` 
# logging on with 1, off with 0
LOGGING=0
LOGFILE=./yessssms.log
phonebook="-"

function log(){
if [ $LOGGING -eq 1 ]; then
  echo "`date -Iseconds` $@" >> $LOGFILE
fi
}

echo $balance_html | grep -i -e Willkommen -e Kontomanager -e yesss > /dev/null
logged_in=$?
if [ $logged_in -gt 0 ]; then
  e="error logging in"
  echo $e
  log $e
  exit -1;
fi

echo $BAL
echo $BAL | egrep "^Verbleibend:.*" > /dev/null
ret=$?
echo $GUT | egrep "^EUR" > /dev/null
ret2=$?
if [ $ret -gt 0 -a $ret2 -gt 0 ]; then
  e="error reading balance"
  echo $e
  log $e
#  exit -1;
fi
BAL=`echo $BAL| sed 's/Verbleibend: \([0-9]*[\.,]*[0-9]*\)/\1 Minuten\/SMS/g'`
#echo "session ID: $SESSID"
echo "balance: $BAL$GUT"


if ! test -z $1; then
  #if [ "$2" == "-" -o -z "$2" ]; then
  if [ "$2" == "-" ]; then
    # read from STDIN
    echo "read from stdin"
    mess=$(</dev/stdin)
    mess=`echo "$mess" | cut -b -160` 
  else
    mess=`echo "$2" | cut -b -160`
  fi
  test -z "$mess" && echo "$0 <number with 0043650...> \"message in quotes\"" && exit -4

  echo "sending SMS..."
  echo "number: $num"
  echo "message: $mess"
  sleep 2 # a chance to abort!

  # encoding chars manually, --data-urlencode exits without success on website
  mess_encoded=`echo -n $mess | sed 's/%/%25/g;s/+/%2B/g;s/@/%40/g;s/ /%20/g;s/\!/%21/g;s/\"/%22/g;s/#/%23/g;s/&/%26/g;s/(/%28/g;s/)/%29/g;s/*/%2A/g;s#/#%2F#g;s/|/%7C/g;'`
  #echo "encoded message: $mess_encoded" 
  curl -s -A "$UA" -b "$SESSID" -o /dev/null -d "to_nummer=$num&telefonbuch=$phonebook&nachricht=$mess_encoded" https://www.yesss.at/kontomanager.at/websms_send.php
  if [ $? -gt 0 ]; then
    e="error sending message"
    echo $e
    log "$e to $num"
    exit -2;
  fi
fi

log "SMS to $num: $mess"

#sleep 4 # wait a little before logging out
#echo "logging out"
curl -s -o /dev/null -A "$UA" -b "$SESSID" https://www.yesss.at/kontomanager.at/index.php?dologout=2
if [ $? -gt 0 ]; then
  e="error logging out"
  echo $e
  log $e
  exit -3;
fi

