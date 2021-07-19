#!/bin/bash
#set -x
ZABBIX_HOME="/etc/zabbix/"
DNS_TEMP="$ZABBIX_HOME/temp"
LISTA_DNSBL="$TEMP_DNS/blacklists.result"

# Verifica se a lista com as Blacklists existe. Se não, cria.
#if [ ! -e $LISTA_DNSBL ]
#then
#	$ZABBIX_HOME/scripts/dnsbl.sh ml
#fi

LISTA_QTD=`$ZABBIX_HOME/scripts/dnsbl.sh co`

retorno=`echo -e "{\n\t\t"\"data\"":["`
for p in `$ZABBIX_HOME/scripts/dnsbl.sh ls`
do
	lista_nome="$(echo $p|cut -d '|' -f 2)"
	lista_url="$(echo $p|cut -d '|' -f 3)"
	if [ "$LISTA_QTD" -le "1" ]
	then
	retorno=$retorno"$(echo "\n\t\t{\n\t\t\t\"{#LISTA_NOME}\":\"$lista_nome\",")"
	retorno=$retorno"$(echo "\n\t\t\t\"{#LISTA_URL}\":\"$lista_url\"}]}")"
		else
		retorno=$retorno"$(echo "\n\t\t{\n\t\t\t\"{#LISTA_NOME}\":\"$lista_nome\",")"
		retorno=$retorno"$(echo "\n\t\t\t\"{#LISTA_URL}\":\"$lista_url\"},")"
	fi
LISTA_QTD=$(($LISTA_QTD - 1))
done
#retorno=$retorno`echo -e "]"`
echo -e $retorno
