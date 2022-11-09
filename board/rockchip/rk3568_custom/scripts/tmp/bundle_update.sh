#!/bin/bash

TOP_DIR=$(pwd)
SCRIPT=$(readlink -f "${BASH_SOURCE[0]}")
BUNDLE_DIR=$(dirname $SCRIPT)
pwd_path=""
list_path="$BUNDLE_DIR/.project.list"

ALL_OFF="\e[0m"
BOLD="\e[1m"
GREEN="${BOLD}\e[32m"
RED="${BOLD}\e[31m"
YELLOW="${BOLD}\e[33m"
BLUE="${BOLD}\e[34m"

function gitt(){
	local pro=$(pwd)
	if [ "$pwd_path" != "$pro" ];then
		pwd_path=$pro
		echo -e "${BOLD}#####################################################${ALL_OFF}"
		echo -e ""
		echo -e ""
		echo -e "${BOLD}#####################################################${ALL_OFF}"
		echo -e -n "${BOLD}# ${ALL_OFF}"
		echo -e "${BLUE}PRO: $pro ${ALL_OFF}"
		echo -e "${BOLD}#####################################################${ALL_OFF}"
	fi
	echo -e -n "${BOLD}# ${ALL_OFF}"
	echo -e "${YELLOW}CMD: git $@ ${ALL_OFF}"
	git $@
	ret="$?"
	if [ "$ret" != "0" ];then
		echo -e -n "${BOLD}# ${ALL_OFF}"
		echo -e "${RED}ERR: $ret ${ALL_OFF}"

		if [ "$IERRORS" = "no" ];then
			exit -1
		fi
	else
		echo -e -n "${BOLD}# ${ALL_OFF}"
		echo -e "${GREEN}PAS: $ret ${ALL_OFF}"
	fi
}

function update_bundle(){
	err_list="$BUNDLE_DIR/.update_bundle.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi
	
	tag2=$(echo $BUNDLE_DIR | awk -F '-to-' '{print $NF}')
	tag1=$(echo $BUNDLE_DIR | awk -F '-to-' '{print $1}' | awk -F '-' '{print $NF}')
	SOC=$(echo $BUNDLE_DIR | awk -F '/' '{print $NF}' | awk -F '-' '{print $1}')
	bundle=$(echo $BUNDLE_DIR | awk -F '/' '{print $NF}')
	bundle="$bundle.bundle"
	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $TOP_DIR/$pro
		
		gitt branch

		if git tag | grep -q $tag1;then
			if git tag | grep -q $tag2;then
				echo -e "${YELLOW}WARN: already updated ${ALL_OFF}"
				sed -i "1d" $err_list
				continue
			fi
		else
			echo -e "${RED}ERR: no tag:$tag1 ${ALL_OFF}"
			exit -1
		fi
		_tag=$(git tag | grep $tag1 | awk -F "$tag1" '{print $1}')
		_tag1="${_tag}${tag1}"
		_tag2="${_tag}${tag2}"

		if [ -f "$BUNDLE_DIR/$pro/$bundle" ];then
			if git branch | grep -q $SOC/firefly;then
				gitt pull $BUNDLE_DIR/$pro/$bundle $_tag2:$SOC/firefly
				gitt checkout $SOC/firefly
			else 
				gitt fetch $BUNDLE_DIR/$pro/$bundle $_tag2:$SOC/firefly
				gitt checkout $SOC/firefly
			fi
		else
			gitt tag $_tag2 $_tag1
		fi
		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

update_bundle
