#!/bin/bash

error() { echo -e "\e[91m$1\e[m"; exit 0; }
success() { echo -e "\e[92m$1\e[m"; }

if [ ! -f /ip2proxy.conf ]; then
	text_error "Missing configuration file."
fi

TOKEN=$(grep 'TOKEN' /ip2proxy.conf | cut -d= -f2)
CODE=$(grep 'CODE' /ip2proxy.conf | cut -d= -f2)
IP_TYPE=$(grep 'IP_TYPE' /ip2proxy.conf | cut -d= -f2)
MONGODB_PASSWORD=$(grep 'MONGODB_PASSWORD' /ip2proxy.conf | cut -d= -f2)

text_primary " > Create directory /_tmp "

mkdir /_tmp

[ ! -d /_tmp ] && text_error "[ERROR]" || text_success "[OK]"

cd /_tmp

text_primary " > Download IP2Proxy database "

v

case "$CODE" in
	PX1|PX1IPV6|PX1LITECSV|PX1LITECSVIPV6 )
		FIELDS=',country_code,country_name'
	;;

	PX2|PX2IPV6|PX2LITECSV|PX2LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name'
	;;

	PX3|PX3IPV6|PX3LITECSV|PX3LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name'
	;;

	PX4|PX4IPV6|PX4LITECSV|PX4LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp'
	;;

	PX5|PX5IPV6|PX5LITECSV|PX5LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain'
	;;

	PX6|PX6IPV6|PX6LITECSV|PX6LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type'
	;;

	PX7|PX7IPV6|PX7LITECSV|PX7LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as'
	;;

	PX8|PX8IPV6|PX8LITECSV|PX8LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen'
	;;

	PX9|PX9IPV6|PX9LITECSV|PX9LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat'
	;;

	PX10|PX10IPV6|PX10LITECSV|PX10LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat'
	;;

	PX11|PX11IPV6|PX11LITECSV|PX11LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat,provider'
	;;
	
	PX12|PX12IPV6|PX12LITECSV|PX12LITECSVIPV6 )
		FIELDS=',proxy_type, country_code,country_name,region_name,city_name,isp,domain,usage_type,asn,as,last_seen,threat,provider,fraud_score'
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

rm -rf /_tmp

text_success "   [UPDATE COMPLETED]"