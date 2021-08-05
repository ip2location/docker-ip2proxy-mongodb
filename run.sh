#!/bin/bash

error() { echo -e "\e[91m$1\e[m"; exit 0; }
success() { echo -e "\e[92m$1\e[m"; }

if [ -f /config ]; then
	mongod --fork --logpath /var/log/mongodb/mongod.log --auth --bind_ip_all
	tail -f /dev/null
fi

if [ "$TOKEN" == "FALSE" ]; then
	error "Missing download token."
fi

if [ "$CODE" == "FALSE" ]; then
	error "Missing product code."
fi

if [ "$MONGODB_PASSWORD" == "FALSE" ]; then
	error "Missing MongoDB password."
fi

if [ -z "$(echo $CODE | grep 'PX')" ]; then
	error "Download code is invalid."
fi

echo -n " > Create directory /_tmp "

mkdir /_tmp

[ ! -d /_tmp ] && error "[ERROR]" || success "[OK]"

cd /_tmp

echo -n " > Download IP2Proxy database "

wget -O database.zip -q --user-agent="Docker-IP2Proxy/MongoDB" http://www.ip2location.com/download?token=${TOKEN}\&productcode=${CODE} > /dev/null 2>&1

[ ! -f database.zip ] && error "[DOWNLOAD FAILED]"

[ ! -z "$(grep 'NO PERMISSION' database.zip)" ] && error "[DENIED]"

[ ! -z "$(grep '5 TIMES' database.zip)" ] && error "[QUOTA EXCEEDED]"

[ $(wc -c < database.zip) -lt 512000 ] && error "[FILE CORRUPTED]"

success "[OK]"

echo -n " > Decompress downloaded package "

unzip -q -o database.zip

CSV="$(find . -name 'IP2PROXY*.CSV')"

[ -z "$CSV" ] && error "[ERROR]" || success "[OK]"

echo -n " > [MongoDB] Create data directory "
mkdir -p /data/db

if [ $? -ne 0 ] ; then
	error "[ERROR]"
fi

success "[OK]"

echo -n " > [MongoDB] Start daemon "
mongod --fork --logpath /var/log/mongodb/mongod.log --bind_ip_all

if [ $? -ne 0 ] ; then
	error "[ERROR]"
fi

success "[OK]"

echo -n " > [MongoDB] Create admin user "
mongosh << EOF
use admin
db.createUser({user: "mongoAdmin", pwd: "$MONGODB_PASSWORD", roles:["root"]})
exit
EOF

if [ $? -ne 0 ] ; then
	error "[ERROR]"
fi

success "[OK]"

echo -n " > [MongoDB] Shut down daemon "
mongod --shutdown

if [ $? -ne 0 ] ; then
	error "[ERROR]"
fi

success "[OK]"

echo -n " > [MongoDB] Start daemon with authentication "
mongod --fork --logpath /var/log/mongodb/mongod.log --auth --bind_ip_all

if [ $? -ne 0 ] ; then
	error "[ERROR]"
fi

success "[OK]"

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
esac

if [ ! -z "$(echo $CODE | grep 'IPV6')" ]; then
	echo -n " > [MongoDB] Create index fields "
	cat $CSV | awk 'BEGIN { FS="\",\""; } { s1 = "0000000000000000000000000000000000000000"substr($1, 2); s2 = "0000000000000000000000000000000000000000"$2; print "\"A"substr(s1, 1 + length(s1) - 40)"\",""\"A"substr(s2, 1 + length(s2) - 40)"\","$0; }' > ./INDEXED.CSV

	if [ $? -ne 0 ] ; then
		error "[ERROR]"
	fi
	
	success "[OK]"
	
	echo -n " > [MongoDB] Create collection \"ip2proxy_database_tmp\" and import data "
	mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "./INDEXED.CSV" --fields ip_from_index,ip_to_index,ip_from,ip_to$FIELDS

	if [ $? -ne 0 ] ; then
		error "[ERROR]"
	fi
	
	success "[OK]"
	
	echo -n " > [MongoDB] Create index "
	mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin << EOF
use ip2proxy_database
db.ip2proxy_database_tmp.createIndex({ip_from_index: 1, ip_to_index: 1})
exit
EOF
	
	if [ $? -ne 0 ] ; then
		error "[ERROR]"
	fi
	
	success "[OK]"
else
	echo -n " > [MongoDB] Create collection \"ip2proxy_database_tmp\" and import data "
	mongoimport -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin --drop --db ip2proxy_database --collection ip2proxy_database_tmp --type csv --file "$CSV" --fields ip_from,ip_to$FIELDS

	if [ $? -ne 0 ] ; then
		error "[ERROR]"
	fi
	
	success "[OK]"
	
	echo -n " > [MongoDB] Create index "
	mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin << EOF
use ip2proxy_database
db.ip2proxy_database_tmp.createIndex({ip_from: 1, ip_to: 1})
exit
EOF
	if [ $? -ne 0 ] ; then
		error "[ERROR]"
	fi
	
	success "[OK]"
fi

echo -n " > [MongoDB] Rename collection \"ip2proxy_database_tmp\" to \"ip2proxy_database\" "
mongosh -u mongoAdmin -p "$MONGODB_PASSWORD" --authenticationDatabase admin << EOF
use ip2proxy_database
db.ip2proxy_database_tmp.renameCollection("ip2proxy_database", true)
exit
EOF

if [ $? -ne 0 ] ; then
	error "[ERROR]"
fi

success "[OK]"

echo " > Setup completed"
echo ""
echo " > You can now connect to this MongoDB server using:"
echo ""
echo "   mongosh -u mongoAdmin -p \"$MONGODB_PASSWORD\" --authenticationDatabase admin"
echo ""

echo "MONGODB_PASSWORD=$MONGODB_PASSWORD" > /config
echo "TOKEN=$TOKEN" >> /config
echo "CODE=$CODE" >> /config

rm -rf /_tmp

tail -f /dev/null