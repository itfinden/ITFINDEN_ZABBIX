#!/bin/bash
# Script para verificação de reputação de IPs em Blacklists do tipo DNS-BL (baseadas em DNS). Estas consultas são úteis a servidores de E-mail. Estes, devido, geralmente, a invasão de contas, tem seus IPs listados em  Blacklists, impedindo a "circulação" de emails legítimos.
# Autor: Werneck Costa - werneck.costa@gmail.com
# Data: 10/11/14
# Versão: 0.1 - Inicial (criação)
# Versão: 0.2 - adição de servidor DNS diferente do interno ao S.O (Werneck Costa)
# Versão: 0.3 - troca de useragent do wget. O portal das listas, parece estar barrando as consultas
#
# Descrição:
# Recebe como parâmetro um endereço IP, converte (trocando as posições dos Octetos) e consulta um registro DNS específico para cada mantenedor de DNS-BL
# a consulta fica algo parecido com:
# $ dig 122.23.24.177.contacts.abuse.net +short
# e deve se ecaixar em duas situações: ou retorna um endereço "127.0.0.x" ou não retorna nada. O retorno diferente de 'null' indica que o IP pesquisado está inserido em uma DNS-BL.
#
# Dependências:
# wget, curl ou similares: efetuar o download de uma página HTML;
# html2text: extrair e converter formato HTML para texto sem tags;
#
# A fazer (to-do):
## Verificação de requisitos
## -> Verificar 'html2text' e 'wget'
## Verificação da existência do arquivo "$IGNORAR_LISTA_DNSBL" (sem ele, o script não roda) 

#set -x

# Variáveis globais:
#
DNS_SERVER="8.8.8.8"
ZABBIX_HOME=/etc/zabbix
TEMP_DNS="$ZABBIX_HOME/temp"
TEMP_LISTA_DNSBL="$TEMP_DNS/TEMP-blacklists.result"
LISTA_DNSBL="$TEMP_DNS/blacklists.result"
IGNORAR_LISTA_DNSBL="$TEMP_DNS/ignorar-blacklists.txt"

#TEMP_resultado_consulta=$ZABBIX_HOME/temp/resultado-consulta.result

help(){
echo -e "
Script para testar listas de DNS-BL afim de verificar se certo IP está listado como Remetente de SPAM.
-> Uso: 
$(cat `basename $0`|grep -A100 "case \$1"|grep ")"|grep -v "\*"|sed -s 's/\t//g'|tr "\)" " ")
Obs: Todas as opções podem ser utilizadas em siglas ou completas.
"
}

troca_UA(){
#set -x
SEGUNDO=$(date +'%S')

case $SEGUNDO in
	[0-1]*)
	echo "Mozilla/5.0 (SunOS 5.8 sun4u; U) Opera 5.0 [en]"
	;;
	[2-3]*)
        echo "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)"
        ;;
	[4-5]*)
        echo "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.0) Opera 12.14"
        ;;
	*)
	;;
esac
}

converte_ip(){
# Converter o IP para o formato contrário: de 1.2.3.4 para 4.3.2.1
IP_ORIGINAL=$1
IP_SAIDA=`echo $IP_ORIGINAL|awk -F'.' '{print $4"."$3"."$2"."$1}'`
echo $IP_SAIDA
}

montar_lista(){
#	echo "Executar um wget (ou comando similar) para baixar a lista de BLs atualizada, comparando com a anterior existente"
# Verificar se a lista tem mais de x dias;
# Verificar se foi possível utilizar a lista nova (se o download foi corretamente processado)
wget -U "$(troca_UA)" http://multirbl.valli.org/list/ -O $TEMP_LISTA_DNSBL
cat $TEMP_LISTA_DNSBL|html2text -width 200|grep -B1000 " dead "|egrep '^[0-9]'|grep -v "`egrep -v '^#' $IGNORAR_LISTA_DNSBL`"|awk -F' ' '{print $7"|"$2"|"$3}'|egrep '^b'|sort > $LISTA_DNSBL
rm -f $TEMP_LISTA_DNSBL
echo "`date +'%d/%m/%Y - %H:%M:%S'` - Lista $LISTA_DNSBL gerada com sucesso"
}

contar_lista(){
	# Conta a quantidade de entradas na lista de Blacklists
	echo `cat $LISTA_DNSBL|wc -l`
}

listar_lista(){
	cat $LISTA_DNSBL
}

consultar_dnsbl(){

# Teste básico para formatação de IP (evita erros nas consultas posteriores)
if [[ -z "$0" ]] || [[ ! "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
then
	echo "É preciso informar um IP no formato 1.2.3.4"
	exit 1
fi

IP_ORIGINAL="$1"
IP="$(converte_ip $1)"
url_dnsbl=$2

Resultado="$(dig @$DNS_SERVER +short $IP.$url_dnsbl)"

if [ -z "$Resultado" ]
then
#	echo "IP $IP_ORIGINAL não listado na Blacklist $url_dnsbl"
	echo "0"
else 
	if [[ "$Resultado" =~ ^127. ]]
	then
#		echo "IP $IP_ORIGINAL listado na Blacklist $url_dnsbl"
		echo "1"
else
#	echo "Timeout da consulta DNS para $url_dnsbl ou erro no comando 'dig'"
	echo "255"
	fi
fi
}

consultar_dnsbl_todas(){
# Converter o IP para o formato contrário (octetos)
IP_ORIGINAL="$1"
# Função que lê a lista $LISTA_DNSBL, utiliza somente os endereços do tipo 'b' (de Blacklist), e efetua as consultas
        for dnsbl in `cat $LISTA_DNSBL`
        do
	#       tipo=`echo $dnsbl|cut -d ';' -f '1'`
#        	nome_dnsbl=`echo $dnsbl|cut -d ';' -f '2'`
                url_dnsbl=`echo $dnsbl|cut -d '|' -f '3'`
		consultar_dnsbl $IP_ORIGINAL $url_dnsbl
        done
}

case $1 in
#	teste)
#	troca_UA
#	;;
	ml|montar_lista) # Efetua o Download da lista em HMLT, converte para texto puro e monta em um formato "consultável" pelo Scripts.
	montar_lista
	;;
	co|contar_lista) # Informa o tamanho da lista atual. Serve para controlar o Loop e pode ser utilizado como item informativo do Zabbix.
	contar_lista
	;;
	cl|consultar_dnsbl) # Consulta um IP - informado como parâmetro 2 - em uma BlackList -informada como parâmetro 3-.
	consultar_dnsbl $2 $3
	;;
	ct|consultar_dnsbl_todas) # Consulta um IP -informada como parâmetro 2- todas as BlackList. 
	consultar_dnsbl_todas $2
	;;
	ls|listar_lista) # Lista a lista com todas as Blacklists. Utilizado no Discovery e pode ser utilizado como item informativo do Zabbix.
	listar_lista
	;;
	ds|discover) # Executa o discovery, devolvendo os Nomes e URLs das Blacklists -utilizadas no Zabbix- para criação de itens dinâmicos.
	$ZABBIX_HOME/scripts/dnsbl-discovery.sh
	;;
	h|help) # Mostra este Help
	help
	exit 0
	;;
	*)
	help
	exit 1
	;;
esac
