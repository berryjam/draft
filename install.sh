Skip to content
Toggle navigation
This project

Search
 45
PaaS-BJ / paasadm Alm logoCodeClub
Project Repository Review Issues 0 Merge Requests 1 Wiki Settings
Files Commits Branches Tags Contributors Graph Compare Charts BranchHistories Comments
827e26be92686bffff44e36d7a81153536811854
paasadm   scripts   install.sh
liyibo 00382189's avatar
美化交互提示
李一博 00382189 committed 2017-08-31 15:39:57

827e26be
 install.sh 13.1 KB
 0        RawBlameHistoryPermalink EditReplaceDelete
#!/bin/bash
#. ./paas_log.sh  #import paas_log.sh to write log 
#===============================================================================================================#
#   FILENAME:       install.sh                  			                                                   #
#   USAGE:          install paas core version 2.1
#   DESCRIPTION:    the entry point of paas core installation process,you must set some values by following the wizard #
#   PARAMETERS:                                                  												#
#   NOTES:          ---                                                                                         #
#   CREATED:        2017/08/31 08:08:08                                                                         #
#   REVISION:       ---                                                                                         #
#===============================================================================================================#
#
export LOGFILE=${LOGDIR}/install.log  #set log file name
export CONFIG_FILE_PATH=/bootstrap/knowledge/fusionstage_CorebaseHA.yaml  #/example.yaml
export LOGDIR="/var/paas/sys/log"
export LOGFILE=${LOGDIR}/paas_log.log

#*************************************************************#
# Name:         getSysTime                     				 #
# Description:  get the system time 	      				 #
# Input:        ---       									 #
# Ouput:        Time: 2009-11-03 09:09:09     				 #
#*************************************************************#
function fn_getSysTime()
{
    isDst=`date | awk '{print $5}'`
    if [[ ${isDst} =~ "DT" ]]
    then
        date "+%Y-%m-%d %T DST"
    else
        date "+%Y-%m-%d %T"
    fi
}

#*************************************************************#
# Name:         LOG                                           #
# Description:  record the message into the logfile           #
# Input:        log message                                   #
# Ouput:        ---                                           #
#*************************************************************#
function LOG()
{
    local strTime=`fn_getSysTime`
    #local strTime='sysdate:'
    local content="$*"

    if [ -z ${LOGFILE} ]
    then
        echo -e "[${strTime}] ${content}"
    elif [  -f ${LOGFILE} ]
    then
        echo -e  "[${strTime}] ${content}" | tee -a ${LOGFILE}
    else
        /bin/mkdir -p `dirname ${LOGFILE}`
        chmod 750 `dirname ${LOGFILE}`
        echo -e  "[${strTime}] ${content}" | tee -a ${LOGFILE}
    fi
}

function INFO()
{
    LOG "INFO: $*"
}

function WARN()
{
    LOG "WARN: $*"
}

function ERROR()
{
    LOG "ERROR: $*"
}


#*************************************************************#
# Name:         PRINT_LOG                                     #
# Description:  print log                                     #
# Input:        $1 the print level                            #
# Ouput:        $2 the log                                    #
#*************************************************************#
function PRINT_LOG()
{
    local LOG_LEVEL=$1
    local LOG_INFO=$2

    if [ -z "${LOGFILE}" ]
    then
        LOGFILE="/tmp/takeover_node_manually.log"
    fi

    case ${LOG_LEVEL} in
        "INFO")
            INFO "${LOG_INFO}"
        ;;
        "WARN")
            WARN "${LOG_INFO}"
        ;;
        "ERROR")
            ERROR "${LOG_INFO}"
        ;;
        *)
            WARN " The LOG_LEVEL must be <INFO|WARN|ERROR>, it will be set to WARN by default ..."
            WARN "${LOG_INFO}"
        ;;
    esac
}

#*************************************************************#
# Name:         prepare_env_and_path                          #
# Description:  prepare env and path                          #
# Input:        ---                                           #
# Ouput:        ---                                           #
#*************************************************************#
function prepare_env_and_path()
{
    echo "[`date`] Begin prepare log file"
    if [ ! -d ${LOGDIR} ]; then
        sudo mkdir -p ${LOGDIR}
    fi
    sudo chown paas:paas -R ${LOGDIR}
    chmod 750 ${LOGDIR}

    if [ ! -f ${LOGFILE} ]; then
        touch ${LOGFILE}
    fi
    chmod 600 ${LOGFILE}
    echo "[`date`] End prepare  log file"
}

PRINT_LOG  "INFO" $LOGFILE

PRINT_LOG  "INFO" "****************************************************************************************************************************************"
PRINT_LOG  "INFO" "#   FILENAME: 	install.sh"
PRINT_LOG  "INFO" "#   USAGE: 		install paas core version 2.1"
PRINT_LOG  "INFO" "#   Description:	the entry point of paas core installation process,you must set some" 
PRINT_LOG  "INFO" "#		values by following the wizard "
PRINT_LOG  "INFO" "#   Assumption: 	Internal assumption:node name of original installation template must in the format of \"name: paas-om-core\""	 
PRINT_LOG  "INFO" "#   PARAMETERS: "
PRINT_LOG  "INFO" "****************************************************************************************************************************************"
PRINT_LOG  "INFO" ""
PRINT_LOG  "INFO" "You will install Paas core version 2.1, please backup your files and ensure there is enough disk space left for 3 target node."
#验证是否继续
read  -p "Continue[Y] or Cancel[Any Key]:" c_continue
if [ "$c_continue" = "Y" ] || [ "$c_continue" = "y" ]; then	
   PRINT_LOG "INFO" "starting installation process......"   
else
	PRINT_LOG "INFO" "exit"
	exit 0
fi

#1.安装前环境变量检查
PRINT_LOG "INFO" "---Phase1:preInstall checking---"

env_result=$(sudo docker ps | wc -l)  #1
if [ $env_result -ne 1 ]; then	
	PRINT_LOG "ERROR" "docker ps result is not null!"
	exit 1
fi;
env_result=$(sudo rpm -qa | grep openv | wc -l) #0
if [ $env_result -ne 0 ]; then	
	PRINT_LOG "ERROR" "openv pkg must be uninstall first!"
	exit 1
fi;

#env_result=$(sudo ls /etc/docker/certs.d | wc -l) #0
if [ -d "/etc/docker/certs.d" ]; then
	PRINT_LOG "ERROR" "/etc/docker/certs.d must be removed!"
	exit 1
fi; 

if [ $? -eq 0 ]; then
	PRINT_LOG "INFO" "---Phase1:preInstall checking success^_^---"
else
	PRINT_LOG "ERROR" "---Phase1:preInstall checking failed!!!---"
	exit 1
fi

#2.解压安装介质
PRINT_LOG "INFO" "---Phase2:Unzip installation image---"
PRINT_LOG "INFO" "          Caution:##This phase will erase the root path for FusionStageCore installation,please backup files first!##"
read  -p "Enter install image path of FusionStageCore & FusionStage-Omlite:[/var/paas/.tool]" c_install_path
if [ ! -n "$c_install_path" ]; then
	c_install_path="/var/paas/.tool"	
fi
PRINT_LOG "INFO" "...The install image path is $c_install_path"
#2.1检查安装介质
is_core_exist=$(ls -l $c_install_path/FusionStageCore-* |grep "^-" | wc -l)
is_omlite_exist=$(ls -l $c_install_path/FusionStage-Omlite-* |grep "^-" | wc -l)
if [ $is_core_exist -ne 1 ]; then
	core_img_list=$(ls $c_install_path/FusionStageCore-*)
	PRINT_LOG "ERROR" "Can not identify PaasCore installation image in the path;detail file list is:$core_img_list"
	exit 1
fi;
if [ $is_omlite_exist -ne 1 ]; then
	omlite_img_list=$(ls $c_install_path/FusionStage-Omlite-*)
	PRINT_LOG "ERROR" "Can not identify OMLite installation image in the path;detail file list is:$omlite_img_list"
	exit 1
fi;


#read  -p "Enter the root path for FusionStageCore installation:[/var/paas]" c_core_bath_path
read  -p "Root path for FusionStageCore installation is default to [/var/paas], any key to continue?"  c_2_continue
if [ ! -n "$c_core_bath_path" ]; then
	c_core_bath_path="/var/paas"
fi;
#PRINT_LOG "INFO" "...The root path for FusionStageCore installation is $c_core_bath_path"
#2.2检查安装root路径
if [ ! -d $c_core_bath_path ]; then
   mkdir $c_core_bath_path
fi
#PRINT_LOG "INFO" "...Unzip FusionStageCore installation image to path: $c_core_bath_path"
read  -p "......Unzip FusionStageCore installation image to path: $c_core_bath_path, any key to continue?" c_2_continue
unzip $c_install_path/FusionStageCore-* -d $c_core_bath_path  #0.1.3.zip
read  -p "...Unzip FusionStage-Omlite installation image to path: $c_core_bath_path/bootstrap, any key to continue?" c_2_continue
#PRINT_LOG "INFO" "...Unzip FusionStage-Omlite installation image to path: $c_core_bath_path"
unzip $c_install_path/FusionStage-Omlite-* -d $c_core_bath_path/bootstrap  #0.1.8.5.zip
chmod +x $c_core_bath_path/bootstrap/bin/*

if [ $? -eq 0 ]; then
	PRINT_LOG "INFO" "---Phase2:Unzip installation image success^_^---"
else 
	PRINT_LOG "ERROR" "---Phase2:Unzip installation image failed!!!---"
	exit 1
fi
#3.config installation parameters
#3.1get confi infor
PRINT_LOG "INFO" "---Phase3:Config installation parameters---"
#read  -p "Enter node IP with \"NodeName:IP\" format,ex:NodeName1:IP1 NodeName2:IP2 NodeName3:IP3 ...: " c_ip_list
read  -p "Enter node IP list with \"IP1 IP2 IP3 ... \" format:" c_ip_list
read  -p "Enter Cluster VIP:" c_vip
PRINT_LOG "INFO" "...Cluster VIP is: $c_vip"
#网段Ip
c_subset_ip=${c_vip%%.*} #截取从右边数最后一个.之右的内容
PRINT_LOG "INFO" "...Subset IP is:$c_subset_ip"
read  -p "Enter External Cluster VIP:" c_external_vip
PRINT_LOG "INFO" "...External Cluster VIP is: $c_external_vip"
read  -s -p "Enter Paas password:" c_password
PRINT_LOG "INFO" "...Paas password is: $c_password"
#3.2更新文件内容
#:<<eof
#line1=${arr[0]};node_arr1=(${line1//:/ })     #:为分隔符，分割为数组
#line2=${arr[1]};node_arr2=(${line2//:/ })
#line3=${arr[2]};node_arr3=(${line3//:/ })
#PRINT_LOG "INFO" "NodeName: ${node_arr1[0]} ,NodeIp:${node_arr1[1]}"
#PRINT_LOG "INFO" "NodeName: ${node_arr2[0]} ,NodeIp:${node_arr2[1]}"
#PRINT_LOG "INFO" "NodeName: ${node_arr3[0]} ,NodeIp:${node_arr3[1]}"  
#eof  


#sed -i -n 's/^meng.*$/haha/g'   # ^ .*$ 描述通配符内的字符,替换满足通配符的单行
#sed -i '/meng/,/kjkl/s/.*/haha/g' file.txt    #替换行之间的内容  每行数据都填充为haha
#以name: paas-om-core作为节点信息的识别位置，+1行为IP信息
PRINT_LOG "INFO" $c_core_bath_path$CONFIG_FILE_PATH
#sed -i 's@\(.*password:\).*$@\1 Huawei\@123@g' bootstrap/knowledge/fusionstage_CorebaseHA.yaml
#set -x
IFS=" " 
arr=($c_ip_list) 
node_index=1
for line in ${arr[@]}  # 以IFS 为分隔符，分割为数组
do     
    #临时取消名称修改，line的格式Node:IP-->IP
	#node_arr=(${line//:/ })     #:为分隔符，分割为数组
	#node_name=${node_arr[0]}
	#node_ip=${node_arr[1]}    
	node_ip=$line
    #:更新文件内容 '/^.*name: paas-om-core1.*$/
    line_num=$(sed -n -e "/name: paas-om-core$node_index/=" $c_core_bath_path$CONFIG_FILE_PATH)  #$c_core_bath_path$CONFIG_FILE_PATH #查找指定行号	
	#sed -i -e "$line_num s/^.*name: paas-om-core.*$/	-name: $node_name/" $c_core_bath_path$CONFIG_FILE_PATH #替换指定行的内容:NodeName	
	line_num=$(($line_num+1))	
	if [ $node_index = 1 ]; then
		sed -i "$line_num s@\(.*ip:\).*\$@\1 \"$node_ip\"@g" $c_core_bath_path$CONFIG_FILE_PATH #替换指定行的内容:NodeIp	   
	   #sed -i '11 s@\(.*ip:\).*$@\1 \"192.168.1.2\"@g' /var/paas/bootstrap/knowledge/fusionstage_CorebaseHA.yaml		
		line_num=$(($line_num+1))
		sed -i "$line_num s@\(.*vip:\).*\$@\1 \"$c_vip\"@g" $c_core_bath_path$CONFIG_FILE_PATH 		#vip
		line_num=$(($line_num+1))				
		sed -i "$line_num s@\(.*externalvip:\).*\$@\1 \"$c_external_vip\"@g" $c_core_bath_path$CONFIG_FILE_PATH #externalvip
	else
		sed -i "$line_num s@\(.*ip:\).*\$@\1 \"$node_ip\"@g" $c_core_bath_path$CONFIG_FILE_PATH #替换指定行的内容:NodeIp	
	fi	
    node_index=$(($node_index+1))    
done

#使用变量用双引号，不使用用单引号
sed -i "s@\(.*cfe_bootstrap_data_network:\).*\$@\1 $c_subset_ip.0.0.0\/8@g" $c_core_bath_path$CONFIG_FILE_PATH #$c_core_bath_path$CONFIG_FILE_PATH
sed -i "s@\(.*cfe_bootstrap_network:\).*\$@\1 $c_subset_ip.0.0.0\/8@g" $c_core_bath_path$CONFIG_FILE_PATH #$c_core_bath_path$CONFIG_FILE_PATH
#查找userinfo:用于定位
line_num=$(sed -n -e "/userinfo:/=" $c_core_bath_path$CONFIG_FILE_PATH)
line_num=$(($line_num+2))
sed -i "$line_num s/\(.*password:\).*\$/\1 $c_password/g" $c_core_bath_path$CONFIG_FILE_PATH       #password

if [ $? -eq 0 ]; then
	PRINT_LOG "INFO" "---Phase3:Config installation parameters success^_^---"
else 
	PRINT_LOG "ERROR" "---Phase3:Config installation parameters failed!!!---"
	exit 1
fi
#4.run autoconfig to generate 
PRINT_LOG "INFO" "---Phase4:Generate installation information---"
read  -p "......start to Generate installation information, any key to continue?" c_2_continue
cd $c_core_bath_path/bootstrap/bin/;./fsadm config CorebaseHA -m base -f ../knowledge/fusionstage_CorebaseHA.yaml
#todo:判断配置是否成功，否则不启动phase5
if [ $? -eq 0 ]; then
	PRINT_LOG "INFO" "---Phase4:Generate installation information success^_^---"
else 
	PRINT_LOG "ERROR" "---Phase4:Generate installation information failed!!!---"
	exit 1
fi

#5.lanch install workflow process
PRINT_LOG "INFO" "---Phase5:lanch install workflow process---"
read  -p "......start to lanch install workflow process, any key to continue?" c_2_continue
cd $c_core_bath_path/bootstrap/bin/;ulimit -n 4096;ulimit -n;cd $c_core_bath_path/bootstrap/bin/;./fsadm createCore CorebaseHA -r 1 #-r 1
if [ $? -eq 0 ]; then
	PRINT_LOG "INFO" "---Phase5:lanch install workflow process success^_^---"
else 
	PRINT_LOG "ERROR" "---Phase5:lanch install workflow process failed!!!---"
	exit 1
fi
