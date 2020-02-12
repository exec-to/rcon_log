#!/bin/bash

RCON_HOME="/opt/rcon"
STATUS_FILE="${RCON_HOME}/var/rcon.status"
CONF_FILE="${RCON_HOME}/etc/rconrc"

source "${RCON_HOME}/etc/config";

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}


function main()
{
  killall -v -9 rcon 2>/dev/null;

  SRV_LIST=$(cat "${CONF_FILE}" | grep  '\[' | cut -d'[' -f2 | cut -d']' -f1);

  for srv in ${SRV_LIST}; do
    userid=$(cat "${CONF_FILE}"| grep "\[$srv\]" -A 1 | tail -n 1 | awk '{print $NF}');

    /usr/bin/rcon -s ${srv} status > ${STATUS_FILE};
    gamehost=$(cat ${STATUS_FILE} | grep 'udp/ip' | awk '{print $3}' | cut -d':' -f1);
    gameport=$(cat ${STATUS_FILE} | grep 'udp/ip' | awk '{print $3}' | cut -d':' -f2);
     IP_LIST=$(cat ${STATUS_FILE} | grep '\#' | tail -n +2 | awk '{print $NF}' | cut -d':' -f 1 | sort -u);
  
    for ip in ${IP_LIST}; do
      valid_ip ${ip};
      valid=$?
      if [ ! ${valid} ]; then
        echo "IP is not valid: ${ip}" >> "${RCON_HOME}/var/rcon.log";
        continue;
      fi;

      ip_exist=$(mysql -u${MYSQL_USER} -p${MYSQL_PASS} $MYSQL_DB -s -N -e "SELECT count(*) FROM updates WHERE ipaddr = '${ip}';" 2>>"${RCON_HOME}/var/rcon.log");
      if [ ${ip_exist} -eq "0" ]; then
        mysql -u${MYSQL_USER} -p${MYSQL_PASS} $MYSQL_DB -e "INSERT INTO \`updates\` (\`gamehost\`, \`gameport\`, \`ipaddr\`, \`state\`, \`userid\`) \
        VALUES ('${gamehost}', ${gameport}, '${ip}', FALSE, '${userid}');" 2>>"${RCON_HOME}/var/rcon.log";
      fi;
   
    done;
  done;
}

main
