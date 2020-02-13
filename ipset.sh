#!/bin/bash

# @reboot /usr/sbin/ipset restore -f /ip/ipall.txt
# ipset save -f /ip/ipall.txt

RCON_HOME="/opt/rcon"
RULES="${RCON_HOME}/tmp/rules"
source "${RCON_HOME}/etc/config";

IPT="/sbin/iptables";

IPSET="/sbin/ipset";

mysql -u${MYSQL_USER} -p${MYSQL_PASS} $MYSQL_DB -s -N -e "select id, gamehost, subnet, userid from ipset_rules where state = 0;" > ${RULES} 2>/dev/null;
while IFS= read -r rule
do
        id=$(echo "${rule}" | awk '{print $1}')
  gamehost=$(echo "${rule}" | awk '{print $2}')
    subnet=$(echo "${rule}" | awk '{print $3}')
     chain=$(echo "${rule}" | awk '{print $4}')

# check ipset chain exist
${IPSET} --list "${chain}-ipset" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
  ${IPSET} -N "${chain}-ipset" nethash

  # add Steam and DNS ip ranges
  steam=$(cat ${RCON_HOME}/etc/steam_net)
  for steam_subnet in ${steam}; do
    ${IPSET} -A "${chain}-ipset" "${steam_subnet}"
  done;

  dns=$(cat ${RCON_HOME}/etc/dns_net)
  for dns_subnet in ${dns}; do
    ${IPSET} -A "${chain}-ipset" "${dns_subnet}"
  done;
fi;

# add subnet to ipset chain
${IPSET} -A "${chain}-ipset" "${subnet}" > /dev/null 2>&1

# check iptables chain exist
${IPT} --table filter -n --list ${chain} > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
  #create chain
  ${IPT} -N ${chain}
  
  #create iptables default rules
  ${IPT} -A ${chain} -m set --match-set "${chain}-ipset" src -j ACCEPT
  ${IPT} -A ${chain} -j DROP;
fi;

# check gamehost rule exist
${IPT} -C FORWARD -d "${gamehost}" -j "${chain}" > /dev/null 2>&1
if [ "$?" -ne "0" ]; then
  ${IPT} -I FORWARD -d "${gamehost}" -j "${chain}"
fi;

# update mysql state
mysql -u${MYSQL_USER} -p${MYSQL_PASS} $MYSQL_DB -e "UPDATE ipset_rules SET state = 1 WHERE id = ${id}" 2>/dev/null;
done < "${RULES}"

