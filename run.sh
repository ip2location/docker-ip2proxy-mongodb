#!/bin/bash

text_primary() { echo -n " $1 $(printf '\055%.0s' {1..70})" | head -c 70; echo -n ' '; }
text_success() { printf "\e[00;92m%s\e[00m\n" "$1"; }
text_danger() { printf "\e[00;91m%s\e[00m\n" "$1"; exit 0; }

USER_AGENT="Mozilla/5.0+(compatible; IP2Proxy/MongoDB-Docker; https://hub.docker.com/r/ip2proxy/mongodb)"
CODES=("PX1-LITE PX2-LITE PX3-LITE PX4-LITE PX5-LITE PX6-LITE PX7-LITE PX8-LITE PX9-LITE PX10-LITE PX11-LITE PX1 PX2 PX3 PX4 PX5 PX6 PX7 PX8 PX9 PX10 PX11 PX12")

if [ -f /ip2proxy.conf ]; then
	mongod --fork --logpath /var/log/mongodb/mongod.log --auth --bind_ip_all
	tail -f /dev/null
fi

if [ "$TOKEN" == "FALSE" ]; then
	text_danger "Missing download token."
fi

if [ "$CODE" == "FALSE" ]; then
	text_danger "Missing product code."
fi

if [ "$MONGODB_PASSWORD" == "FALSE" ]; then
	text_danger "Missing MongoDB password."
fi

if [ -z "$(echo $CODE | grep 'PX')" ]; then
	text_danger "Download code is invalid."
fi

FOUND=""
for i in "${CODES[@]}"; do
	if [ "$i" == "$CODE" ] ; then
		FOUND="$CODE"
	fi
done

if [ -z $FOUND == "" ]; then
	text_error "Download code is invalid."
fi

CODE=$(echo $CODE | sed 's/-//')

text_primary " > Create directory /_tmp "

mkdir /_tmp

[ ! -d /_tmp ] && text_error "[ERROR]" || text_success "[OK]"

cd /_tmp

text_primary " > Download IP2Proxy database "

if [ "$IP_TYPE" == "IPV4" ]; then
	wget -O ipv4.zip -q --user-agent="$USER_AGENT" "https://www.ip2location.com/download?token=${TOKEN}&code=${CODE}CSV" > /dev/null 2>&1

	[ ! -z "$(grep 'NO PERMISSION' ipv4.zip)" ] && text_error "[DENIED]"
	[ ! -z "$(grep '5 TIMES' ipv4.zip)" ] && text_error "[QUOTA EXCEEDED]"

	RESULT=$(unzip -t ipv4.zip >/dev/null 2>&1)

	[ $? -ne 0 ] && text_error "[FILE CORRUPTED]"
else
	wget -O ipv6.zip -q --user-agent="$USER_AGENT" "https://www.ip2location.com/download?token=${TOKEN}&code=${CODE}CSVIPV6" > /dev/null 2>&1

	[ ! -z "$(grep 'NO PERMISSION' ipv6.zip)" ] && text_error "[DENIED]"
	[ ! -z "$(grep '5 TIMES' ipv6.zip)" ] && text_error "[QUOTA EXCEEDED]"

	RESULT=$(unzip -t ipv6.zip >/dev/null 2>&1)

	[ $? -ne 0 ] && text_error "[FILE CORRUPTED]"
fi

text_success "[OK]"

for ZIP in $(ls | grep '.zip'); do
	CSV=$(unzip -l $ZIP | grep -Eo 'IP2PROXY-IP(V6)?.*CSV')

	text_primary " > Decompress $CSV from $ZIP "

	unzip -jq $ZIP $CSV

	if [ ! -f $CSV ]; then
		text_error "[ERROR]"
	fi

	text_success "[OK]"
done

text_primary " > [MongoDB] Start daemon "
mongod --fork --logpath /var/log/mongodb/mongod.log --bind_ip_all

[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

text_primary " > [MongoDB] Create admin user "
mongosh << EOF
use admin
db.createUser({user: "mongoAdmin", pwd: "$MONGODB_PASSWORD", roles:["root"]})
exit
EOF

[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

text_primary " > [MongoDB] Shut down daemon "
mongod --shutdown

[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

text_primary " > [MongoDB] Start daemon with authentication "
mongod --fork --logpath /var/log/mongodb/mongod.log --auth --bind_ip_all

[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

case "$CODE" in
	PX1|PX1IPV6|PX1LITECSV|PX1LITECSVIPV6 )
		FIELDS=',country_code,country_name'
	;;

	PX2|PX2IPV6|PX2LITECSV|PX2LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name'
	;;

	PX3|PX3IPV6|PX3LITECSV|PX3LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name'
	;;

	PX4|PX4IPV6|PX4LITECSV|PX4LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp'
	;;

	PX5|PX5IPV6|PX5LITECSV|PX5LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain'
	;;

	PX6|PX6IPV6|PX6LITECSV|PX6LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type'
	;;

	PX7|PX7IPV6|PX7LITECSV|PX7LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as'
	;;

	PX8|PX8IPV6|PX8LITECSV|PX8LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen'
	;;

	PX9|PX9IPV6|PX9LITECSV|PX9LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat'
	;;

	PX10|PX10IPV6|PX10LITECSV|PX10LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat'
	;;

	PX11|PX11IPV6|PX11LITECSV|PX11LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat,provider'
	;;
	
	PX12|PX12IPV6|PX12LITECSV|PX12LITECSVIPV6 )
		FIELDS=',proxy_type,country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat,provider,fraud_score'
	;;
esac

if [ ! -z "$(echo $CODE | grep 'IPV6')" ]; then
	text_primary " > [MongoDB] Create index fields "
	cat $CSV | awk 'BEGIN { FS="\",\""; } { s1 = "0000000000000000000000000000000000000000"substr($1, 2); s2 = "0000000000000000000000000000000000000000"$2; print "\"A"substr(s1, 1 + length(s1) - 40)"\",""\"A"substr(s2, 1 + length(s2) - 40)"\","$0; }' > ./INDEXED.CSV

	[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

	text_primary " > [MongoDB] Create collection \"ip2proxy_database_tmp\" and import data "
	mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "./INDEXED.CSV" --fields ip_from_index,ip_to_index,ip_from,ip_to$FIELDS

	[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

	text_primary " > [MongoDB] Create index "
	mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin << EOF
use ip2proxy_database
db.ip2proxy_database_tmp.createIndex({ip_from_index: 1, ip_to_index: 1})
exit
EOF

	[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"
else
	text_primary " > [MongoDB] Create collection \"ip2proxy_database_tmp\" and import data "
	mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "$CSV" --fields ip_from,ip_to$FIELDS

	[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

	text_primary " > [MongoDB] Create index "
	mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin << EOF
use ip2proxy_database
db.ip2proxy_database_tmp.createIndex({ip_from: 1, ip_to: 1})
exit
EOF
	[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"
fi

text_primary " > [MongoDB] Rename collection \"ip2proxy_database_tmp\" to \"ip2proxy_database\" "
mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin << EOF
use ip2proxy_database
db.ip2proxy_database_tmp.renameCollection("ip2proxy_database", true)
exit
EOF

[ $? -ne 0 ] && text_danger "[ERROR]" || text_success "[OK]"

echo " > Setup completed"
echo ""
echo " > You can now connect to this MongoDB server using:"
echo ""
echo "   mongosh -u mongoAdmin -p \"$MONGODB_PASSWORD\" --authenticationDatabase admin"
echo ""

echo "MONGODB_PASSWORD=$MONGODB_PASSWORD" > /ip2proxy.conf
echo "TOKEN=$TOKEN" >> /ip2proxy.conf
echo "CODE=$CODE" >> /ip2proxy.conf
echo "IP_TYPE=$IP_TYPE" >> /ip2proxy.conf

rm -rf /_tmp

tail -f /dev/null