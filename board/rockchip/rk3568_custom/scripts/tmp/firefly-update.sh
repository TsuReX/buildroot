#!/bin/bash

#其他平台可能需要修改此处
version=$(readlink -f .repo/manifest.xml | awk -F '/' '{print $NF}')
SOC=$(echo $version | awk -F '_' '{print $1}')
if [ "$SOC" == "rv1126" ];then
	check=$(echo $version | grep ai_camera)
	if [ x"$check" == x ];then
		SOC="rv1126_rv1109"
	else
		SOC="rv1126_rv1109_ai"
	fi
fi
##################

list_path=".project.list"
all_cmd=".repo/repo/repo forall -c"
current_branch="current"
firefly_branch="$SOC/firefly"
rockchip_branch="$SOC/rockchip"
firefly="firefly-linux"
gitlab="firefly-gitlab"

ALL_OFF="\e[0m"
BOLD="\e[1m"
GREEN="${BOLD}\e[32m"
RED="${BOLD}\e[31m"
YELLOW="${BOLD}\e[33m"
BLUE="${BOLD}\e[34m"
pwd_path=""

# 存放子进程 PID 号
PID_FILE="/tmp/.firefly.PID"
# 多进程数目
process_num=1
# 超时时间
timeout_seconds="600"

#ignore error
IERRORS="no"

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

function project_list(){
	list_path=".project.list"
	manifest_file="../manifest.xml"
	save_file=$manifest_file
	cd .repo/manifests/
	while [ x"$save_file" != x ];
	do
		save_file=$(cat $save_file | grep "include name" |awk -F '"' '{print $2}')
		manifest_file="$manifest_file $save_file"
	done
	cd - > /dev/null

	rm -rf $list_path
	for i in $manifest_file
	do
		cat .repo/manifests/$i | grep -v "<!--"| grep "<project"  | while read line
		do
	        	check=$(echo $line | grep "path=")
	        	if [ x"$check" == x ];then
	           		pro=$(echo $line | grep "<project" | awk -F 'name' '{print $2}'| awk -F '"' '{print $2}')
	        	else
	               		pro=$(echo $line | grep "<project" | awk -F 'path' '{print $2}'| awk -F '"' '{print $2}')
	        	fi

	        	branch=$(echo $line | grep "<project" | awk -F 'dest-branch' '{print $2}'| awk -F '"' '{print $2}')
        		if [ x"$branch" == x ];then
	        		branch=$(echo $line | grep "<project" | awk -F 'revision' '{print $2}'| awk -F '"' '{print $2}')
        			if [ x"$branch" == x ];then
					branch=$SOC/firefly
				fi
			fi
			echo $pro $branch >> $list_path
		done
	done
}

function push_firefly(){
	project_list
	err_list=".push_firefly.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro
		if git branch | grep -q $firefly_branch; then
			gitt push $firefly $firefly_branch:$bra
		else
			exit -1
		fi
		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function push_gitlab(){
	project_list
	err_list=".push_gitlab.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro
		if git branch | grep -q $firefly_branch; then
			gitt push $gitlab $firefly_branch:$bra
		else
			exit -1
		fi
		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}


function create_release(){
	project_list
	release=$1
	err_list=".create_release.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $firefly_branch; then
			gitt checkout $firefly_branch
			gitt branch $release
			gitt push $firefly $release:$release
		else
			exit -1
		fi


		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function tag_release(){
	project_list
	branch=$1
	tag=$2
	err_list=".tag_release.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $branch; then
			gitt checkout $branch
			gitt tag $tag
			gitt checkout $firefly_branch
			gitt merge --no-ff $branch
			gitt push $firefly $tag
			gitt push $firefly $firefly_branch:$bra
		else
			exit -1
		fi


		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function delete_release(){
	project_list
	branch=$1
	err_list=".delete_release.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $firefly_branch; then
			gitt checkout $firefly_branch
		else
			exit -1
		fi

		if git branch --no-merged | grep -q repo_sync;then
			echo -e "# ${RED}ERR: Please check if the branch has been merged!${ALL_OFF}"
			exit -1
		fi

		gitt branch -D $branch
		gitt push $firefly :$branch

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function pull_branch(){
	project_list
	branch=$1
	err_list=".pull_branch.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $branch; then
			gitt checkout $branch
			gitt pull $firefly $branch:$branch
		else
			exit -1
		fi


		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function push_branch(){
	project_list
	branch=$1
	err_list=".push_branch.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $branch; then
			gitt push $firefly $branch:$branch
		else
			exit -1
		fi


		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}


function tag_local_firefly(){
	project_list
	tag=$1
	err_list=".tag_local_firefly.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $firefly_branch; then
			gitt checkout $firefly_branch
		else
			exit -1
		fi
		gitt tag $tag

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function tag_firefly(){
	project_list
	tag=$1
	err_list=".tag_firefly.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $firefly_branch; then
			gitt checkout $firefly_branch
		else
			exit -1
		fi
		gitt push $firefly $tag

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function tag_gitlab(){
	project_list
	tag=$1
	err_list=".tag_gitlab.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $firefly_branch; then
			gitt checkout $firefly_branch
		else
			exit -1
		fi
		gitt push $gitlab $tag

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}


function trap_exit(){
	# 关闭${fifo_num}管道
	echo eval exec "${fifo_num}"'>'"&-"
	eval exec "${fifo_num}"'>'"&-"

	sleep 0.5
	kill -s 1 $(cat $PID_FILE)

	sleep 0.5
	kill $(ps -aux | grep "timeout -k 1096s"| grep -v grep |awk -F ' ' '{print $2}')

	#wait
	#echo kill $(cat /tmp/.firefly.PID)

	exit
}

function tag_gitlab_multi(){
	project_list
	tag=$1
	err_list=".tag_gitlab.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while_file_num=`wc -l < $while_file`

	# mkfifo
	tempfifo="my_temp_fifo"
	mkfifo ${tempfifo}
	# 使文件描述符为非阻塞式,exec自动分配数值为 ${fifo_num} 的FD号
	exec {fifo_num}<>${tempfifo}
	rm -f ${tempfifo}

	# 为文件描述符创建占位信息
	for ((i=1;i<=${process_num};i++))
	do
	{
		echo ""
	}
	done >&${fifo_num}

	flock $PID_FILE -c "echo -n \"\" > $PID_FILE"

	# ctrl+c kill process
	#trap 'killall firefly-update.sh;"' int

	trap trap_exit SIGINT

	while read line
	do
	{
		# 开始多任务分发
		read -u${fifo_num}
		{
			trap "exit" 1
			# Save PID
			local pid=$BASHPID
			flock $PID_FILE -c "echo $pid >> $PID_FILE"

			sleep 0.3
			pro=$(echo $line | awk -F ' ' '{print $1}')
			bra=$(echo $line | awk -F ' ' '{print $2}')
			cd $pro

			echo -e "[${BLUE} $pro ${ALL_OFF}] ${YELLOW}pushing${ALL_OFF}"
			if git branch | grep -q $firefly_branch; then
				git checkout $firefly_branch > /dev/null 2>&1
			else
				echo -e "[${BLUE} $pro ${ALL_OFF}] not exited ${YELLOW}firefly_branch${ALL_OFF} ${RED}[failed]${ALL_OFF}"
				exit -1
			fi

			# git push $gitlab $tag > /dev/null 2>&1
			# git push $gitlab $tag

			while timeout -k 1096s $timeout_seconds git push $gitlab $tag ; [ $? = 124 ]
			do
			echo -e "[${BLUE} $pro ${ALL_OFF}] pushing [${RED}timed out ${ALL_OFF}]"
			sleep 1.5  # Pause before retry
			echo -e "[${BLUE} $pro ${ALL_OFF}] ${YELLOW}pushing${ALL_OFF}"
			done



			#cd - > /dev/null
			cd - > /dev/null

			# 处理非常痛苦的问题，输入有反斜杠
			# sed -i "s/\//\\\\\//g" test.list
			# sed -i "s/\//d\\\\\//g" test.list
			#       app/QLauncher rk3399/firefly
			# 改为：
			#      app\/QLauncher rk3399\/firefly
			#delete_line=`echo $line| sed  "s/\//d\\\\\/g" `
			delete_line=`echo $line| sed  "s/\//\\\\\\\\\//g" `

			# 使用文件占用锁，当$err_list被释放后执行后面的命令
			flock $err_list -c "sed -i \"/$delete_line/d\" $err_list"

			# 制作进度条
			while_file_unfinish_num=`flock $err_list -c "wc -l < $err_list"`  # err_list 都是未完成的
			while_file_finish_num=`expr $while_file_num - $while_file_unfinish_num`

			echo -e "[${while_file_finish_num}/${while_file_num} ${BLUE} $pro ${ALL_OFF}] push tag($tag) ${GREEN}[successed]${ALL_OFF}"

			# Remove PID
			flock $PID_FILE -c "sed -i \"/$pid/d\" $PID_FILE"

			# 重新分发任务
			echo "" >&${fifo_num}
			#echo flock $err_list -c "sed -i \"/$pro/d\" $err_list"
		} &
	}
	done < $while_file

	wait

	# 关闭${fifo_num}管道
	eval exec "${fifo_num}"'>'"&-"

	rm -rf $err_list
}

function bundle(){
	project_list
	tag1=$1
	tag2=$2
	err_list=".bundle.list"
	bundle_dir=$(pwd)
	_tag1=$(echo $tag1 | awk -F '_' '{print $NF}')
	_tag2=$(echo $tag2 | awk -F '_' '{print $NF}')

	bundle="$SOC-$_tag1-to-$_tag2"

	bundle_dir="$bundle_dir/$bundle"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		rm -rf $bundle_dir
		mkdir $bundle_dir
		while_file="$list_path"
		cp $list_path $err_list
	fi
	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro
		if git branch | grep -q $firefly_branch; then
			gitt checkout $firefly_branch
		else
			exit -1
		fi
		if git log --pretty=format:"%Creset%d" -1 | grep $tag1;then
			cd - > /dev/null
			sed -i "1d" $err_list
			continue
		else
			gitt bundle create $bundle.bundle $tag1..$tag2
		fi

		mkdir -p $bundle_dir/$pro
		mv $bundle.bundle $bundle_dir/$pro

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	cp device/rockchip/common/bundle_update.sh $bundle_dir -p
	cp $list_path $bundle_dir -p

	rm -rf $err_list
}


function gitlab_remote_init(){
	project_list
	tag=$1
	err_list=".gitlab_remote_init.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git remote -v | grep -q $firefly; then
			url=$(git remote -v | grep $firefly | grep -v $gitlab | awk -F ' ' '{print $2}' | uniq | sed "s/.*rk-linux\/\(.*\)*/\1/")
			url="git@gitlab.com:firefly-linux/$url"
			gitt remote add $gitlab $url
		else
			exit -1
		fi

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function reset_manifest(){
	if [ x"$1" != x ] && [ "$1" == "-a" ];then
		all=true
	else
		all=false
	fi

	manifest_path=".repo/manifests/"
	val=$(echo $version | awk -F '_' '{print $1}')
	cd $manifest_path
	if $all ; then
		xml_file=( $(find -name "*.xml" | sort) )
	else
		xml_file=( $(find -name "*.xml"| grep $val | grep -v old | sort) )
	fi
	echo ${xml_file[@]}| xargs -n1 | awk -F '/' '{print $NF}' | sed "=" | sed "N;s/\n/. /"
	read -p "Which would you like? [0]: " INDEX
	INDEX=$((${INDEX:-0} - 1))
	if echo $INDEX | grep -vq [^0-9]; then
	xml=${xml_file[$INDEX]}
	else
		exit -1
	fi
	cd - > /dev/null

	cd .repo
	ln -sf manifests/$xml manifest.xml
	cd - > /dev/null
}



function pull_firefly(){
	.repo/repo/repo sync -cd --no-tags
	if [ "$?" != "0" ];then
		exit -1
	fi

	if [ x"$1" != x ] && [ "$1" == "-f" ];then
		force=true
	else
		force=false
	fi

	project_list
	err_list=".pull_firefly.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if $force ;then
			if git branch | grep -q $firefly_branch;then
				gitt branch -D $firefly_branch
			fi
			gitt checkout -b $firefly_branch
		else
			if git branch | grep -q repo_sync; then
				gitt branch -D repo_sync
			fi
			gitt checkout -b repo_sync
		fi
		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list

}


function pull_rockchip(){
	project_list
	err_list=".pull_rockchip.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		gitt checkout $firefly_branch
		gitt branch -D $rockchip_branch
		gitt fetch $firefly $rockchip_branch
		gitt checkout -b $rockchip_branch $firefly/$rockchip_branch

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function merge_rockchip(){
	project_list
	err_list=".merge_rockchip.list"
	if [ -f "$err_list" ];then
		echo -e "${YELLOW}注意：本次从上次执行失败的仓库开始继续执行! $pro ${ALL_OFF}"
		while_file="$err_list"
	else
		while_file="$list_path"
		cp $list_path $err_list
	fi

	while read line
	do
		pro=$(echo $line | awk -F ' ' '{print $1}')
		bra=$(echo $line | awk -F ' ' '{print $2}')
		cd $pro

		if git branch | grep -q $rockchip_branch; then
			gitt checkout $firefly_branch
			gitt merge --no-ff $rockchip_branch
		else
			exit -1
		fi

		cd - > /dev/null
		sed -i "1d" $err_list
	done < $while_file
	rm -rf $err_list
}

function usage(){
	echo "Usage:"
	echo "常用："
	echo "$0 pull-rockchip - 更新本地 SOC/rockchip 分支，SOC/rockchip 是上游更新分支没有经过任何改动"
	echo "$0 merge-rockchip - Merge SOC/rockchip 到 SOC/firefly"
	echo "$0 pull-firefly [-f] - 更新本地 SOC/firefly 分支，repo sync -c 更新后的最新提交, -f 强制合并到本地分支"
	echo "$0 push-firefly - 更新远程(内部) SOC/firefly 分支"
	echo "$0 push-gitlab - 更新远程(外部) SOC/firefly 分支"
	echo "$0 reset [-a] - 回退到某 manifest xml 版本"

	echo ""
	echo "发布使用："
	echo "$0 create-release release_branch - 根据当前 SOC/firefly 创建临时 release 版本"
	echo "$0 tag-release release_branch tag - 发布分支上打上标签"
	echo "$0 delete-release-branch release_branch - 删除本地和远程的分支"
	echo "$0 tag-firefly tag - 推送标签到远程(内部) firefly-linux"
	echo "$0 tag-gitlab tag - 推送标签到远程(外部) firefly-linux"
	echo "$0 tag-gitlab tag [-j数字] [-t300] - 推送标签到远程(外部) firefly-linux ; -j4 代表创建4个进程加速; -t300 进程超时时间为300秒"

	echo ""
	echo "发布阶段调试："
	echo "$0 pull-branch branch - 拉取分支，但是所有仓库分支必须同名"
	echo "$0 push-branch branch - 推送分支，但是所有仓库分支必须同名"

	echo ""
	echo "不常用："
	echo "$0 tag-local-firefly tag - 本地 SOC/firefly 分支打标签"
	echo "$0 gitlab-remote-init - 初始化外部仓库 remote"
	echo "$0 bundle tag1 tag2 - 生成整个 repo tag1 to tag2 的 bundle"

	echo -e "\nEnvironment variable："
	echo -e "\t\t\tdefault value\t\tnotes"
	echo -e "\tIERRORS\t\tno\t\tIgnore errors when set to yes"

}

OPTIONS="${@:-allff}"

for option in ${OPTIONS}; do
	case $option in
		-j*) process_num=`echo "$option"|sed  "s/-j//g"`
			echo -e "进程数\t$process_num"
			;;
		-t*) timeout_seconds=`echo "$option"|sed  "s/-t//g"`
			echo -e "超时时间\t${timeout_seconds}"
			;;
		*)  ;;
	esac
done


para=$1

if [ "$para" == "pull-rockchip" ];then
	pull_rockchip
elif [ "$para" == "merge-rockchip" ];then
	merge_rockchip
elif [ "$para" == "pull-firefly" ];then
	pull_firefly $2
elif [ "$para" == "push-firefly" ];then
	push_firefly
elif [ "$para" == "push-gitlab" ];then
	push_gitlab
elif [ "$para" == "create-release" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		release=$2
	fi

	create_release $release
elif [ "$para" == "delete-release-branch" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		branch=$2
	fi

	delete_release $branch
elif [ "$para" == "pull-branch" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		branch=$2
	fi

	pull_branch $branch
elif [ "$para" == "push-branch" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		branch=$2
	fi

	push_branch $branch
elif [ "$para" == "tag-release" ];then
	if [ x"$2" == x ] && [ x"$3" == x ];then
		usage
		exit -1
	else
		tag=$3
		branch=$2
	fi

	tag_release $branch $tag
elif [ "$para" == "tag-local-firefly" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		tag=$2
	fi

	tag_local_firefly $tag
elif [ "$para" == "tag-firefly" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		tag=$2
	fi

	tag_firefly $tag
elif [ "$para" == "tag-gitlab" ];then
	if [ x"$2" == x ];then
		usage
		exit -1
	else
		tag=$2
	fi

	if [[ $process_num != 1 ]];then
		tag_gitlab_multi $tag
	else
		tag_gitlab $tag
	fi

elif [ "$para" == "bundle" ];then
	if [ x"$2" == x ] && [ x"$3" == x ];then
		usage
		exit -1
	else
		tag1=$2
		tag2=$3
	fi

	bundle $tag1 $tag2
elif [ "$para" == "reset" ];then
	reset_manifest $2
elif [ "$para" == "gitlab-remote-init" ];then
	gitlab_remote_init $2
else
	usage
fi
