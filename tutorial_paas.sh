#!/bin/bash

serviceName=FusionStageBase
PackageVersion=1.`date '+%y %m%d%H%M'|awk '{print $1}'`.`date '+%y %m%d%H%M'|awk '{print $2}'`
BootstrapPackages=(SWR DBM-1 DBM-installer PSM AOS BootstrapCFE CAM keepalived haproxy)
OtherBasePackages=(HRS FEBS CSE ETCD IAMService)

if [ ! $releaseVersion ]; then
    isRelease=false
    Version=${PackageVersion}
    buildType=Snapshot
else
    isRelease=true
    Version=$releaseVersion
    PackageVersion=$releaseVersion
    buildType=Release
fi

dstPOMDir=/var/paas/baseFsPkg/${buildType}
solution_name_ver=${serviceName}-${PackageVersion}

###################################### paasadm ##########################################
echo -e "\033[1;33m Paasadm Compile Start\033[0m"
echo -e "\033[1;34m Paasadm Compile At: $WORKSPACE\033[0m"

set -ex
sed -i s/POM/${serviceName}/g ./paasadm/app_define.json
rm -rf src; mkdir src
mv paasadm src

export GOROOT=/opt/go
export GOPATH=/var/paas/gopath:/var/paas/workspace/pom_compile
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
export VERSION_TAG=${PackageVersion}

# build paasadm
echo  Current Go Version: `go version`
echo -e "\033[1;33mCompile  Start to build \033[0m"

cd src/paasadm

sed -i s,http://code.huawei.com/,git@code.huawei.com:,g build/build.sh
bash build/build.sh
if [ $? != 0 ];then
   echo -e "\033[1;33mCompile  failed \033[0m"
   exit 1
fi

chown -R paas:paas ./
#######################################################################################


echo -e "\033[1;33m Start to release \033[0m"
echo -e "\033[1;34m Release At: $WORKSPACE\033[0m"

rm -rf   ${WORKSPACE}/svc ${WORKSPACE}/solution ${WORKSPACE}/tmpDir
mkdir -p ${WORKSPACE}/svc ${WORKSPACE}/solution ${WORKSPACE}/tmpDir

mv __output ${WORKSPACE}/solution/bootstrap

# step 1. get all related packages
if [ $releaseVersion ]; then    
  # when doing Release                  >>>>>>>>
  for pkg in "${BootstrapPackages[@]}"
  do
    wget -r -l 1 -np -nd --accept="${pkg}*" http://10.120.195.215:8091 -P ${WORKSPACE}/svc 2>/dev/null
    if [ ! -f ${WORKSPACE}/svc/${pkg}* ]; then
       echo NOTICE: cannot found ${pkg} from ImageLayer DIR. try to replace it with normal packages.

       wget -r -l 1 -np -nd --accept="${pkg}*" http://10.120.195.215:8090 -P ${WORKSPACE}/svc 2>/dev/null
       cnt=`ls -lh  ${WORKSPACE}/svc | grep ${pkg} | wc -l`
       if [ $cnt -lt 1 ]; then
         echo ERROR: cannot found ${pkg}
         exit
       fi
    fi
  done
  
  for pkg in "${OtherBasePackages[@]}"
  do
    if [ ! -f ${WORKSPACE}/svc/${pkg}* ]; then
      wget -r -l 1 -np -nd --accept="${pkg}*" http://10.120.195.215:8091 -P ${WORKSPACE}/svc 2>/dev/null
      if [ ! -f ${WORKSPACE}/svc/${pkg}* ]; then
       echo NOTICE: cannot found ${pkg} from ImageLayer DIR. try to replace it with normal packages.

       wget -r -l 1 -np -nd --accept="${pkg}*" http://10.120.195.215:8090 -P ${WORKSPACE}/svc 2>/dev/null
       cnt=`ls -lh  ${WORKSPACE}/svc | grep ${pkg} | wc -l`
       if [ $cnt -lt 1 ]; then
         echo ERROR: cannot found ${pkg}
         exit
       fi
      fi
      continue
    fi
    echo ${pkg}* already downloaded. skip it.
  done
  
else   
  # when doing Continues Intergration   >>>>>>>>
  cd ${WORKSPACE}
  rm -rf /var/paas/base_pkgs_from_CI/*
  mkdir -p CI_Scripts/
  rm -rf CI_Scripts/*
  cp -r /var/paas/CI_Scripts/* CI_Scripts/
  
  cd CI_Scripts
  
  for pkg in "${BootstrapPackages[@]}"
  do
    bash -x $pkg.sh /var/paas/base_pkgs_from_CI/
    if [ $? != 0 ]; then
      echo download $pkg failed.
      exit 1
    fi
  done
  #bash -x DBM-installer.sh /var/paas/base_pkgs_from_CI/
  
  for pkg in "${OtherBasePackages[@]}"
  do
    bash -x $pkg.sh /var/paas/base_pkgs_from_CI/
    if [ $? != 0 ]; then
      echo download $pkg failed.
      exit 1
    fi
  done
  
  cd -


  for pkg in "${BootstrapPackages[@]}"
  do
    cnt=`ls -lh /var/paas/base_pkgs_from_CI/${pkg}* | wc -l`
    if [[ $cnt -ne 1 ]] && [[  $pkg != "DBM" ]]; then
      echo package count of ${pkg} is not only 1.
      exit 1
    fi
  done
  
  for pkg in "${OtherBasePackages[@]}"
  do
    cnt=`ls -lh /var/paas/base_pkgs_from_CI/${pkg}* | wc -l`
    if [[ $cnt -ne 1 ]] && [[  $pkg != "DBM" ]]; then
      echo package count of ${pkg} is not only 1.
      exit 1
    fi
  done
  cp /var/paas/base_pkgs_from_CI/* ${WORKSPACE}/svc
fi



# step 2. create dirs for solution
solutionDirs=(images charts blueprints bootstrap packages)
for dir in "${solutionDirs[@]}"
do
  mkdir -p ${WORKSPACE}/solution/${dir}
done

# step 3. unzip and update images/blueprints/charts/packages.
mv ${WORKSPACE}/svc/*.tgz ${WORKSPACE}/solution/bootstrap/package
mv ${WORKSPACE}/svc/BootstrapCFE* ${WORKSPACE}/solution/bootstrap/package
unzip ${WORKSPACE}/svc/DBM*.zip -d ${WORKSPACE}/solution/bootstrap/swr

# step 3.1 fetch dependent tools
wget http://10.120.195.215:8091/docker_load -P ${WORKSPACE}/solution/bootstrap/bin  2>/dev/null
chmod +x ${WORKSPACE}/solution/bootstrap/bin/*
wget -r -l 1 -np -nd --accept="*tar.gz" http://10.120.195.215:8091/lib -P ${WORKSPACE}/solution/bootstrap/images/lib   2>/dev/null  # lib dir
wget -r -l 1 -np -nd --accept="*tar.gz" http://10.120.195.215:8091/base  -P ${WORKSPACE}/solution/bootstrap/images/base    2>/dev/null # base dir
wget http://10.120.195.215:8091/EULEROS/euleros-2.2.tar   -P ${WORKSPACE}/solution/bootstrap/images   2>/dev/null

wget http://10.162.197.72:8090/CI_config/common/ca.cer                -P ${WORKSPACE}/solution/bootstrap/cert     2>/dev/null
wget http://10.162.197.72:8090/CI_config/common/ca_key_decrypt.pem    -P ${WORKSPACE}/solution/bootstrap/cert     2>/dev/null
wget http://10.162.197.72:8090/CI_config/common/root.key              -P ${WORKSPACE}/solution/bootstrap/userkey  2>/dev/null
wget http://10.162.197.72:8090/CI_config/common/common_shared.key     -P ${WORKSPACE}/solution/bootstrap/userkey  2>/dev/null
wget http://10.162.197.72:8090/CI_config/common/redis_shared.key      -P ${WORKSPACE}/solution/bootstrap/userkey  2>/dev/null


services=`ls ${WORKSPACE}/svc | grep ".zip$"`

for service in ${services}
do
  service_name=`echo ${service} | sed 's/.zip$//g' | awk -F "-" '{print $1}'`
  unzip -qo ${WORKSPACE}/svc/${service} -d ${WORKSPACE}/tmpDir/${service_name}
  for pkg in "${BootstrapPackages[@]}"
  do
    if [[ ${pkg} = ${service_name} ]] && [[  $pkg != "DBM" ]]; then
      mv ${WORKSPACE}/svc/${service} ${WORKSPACE}/solution/bootstrap/package
    fi
    
    if [[ ${pkg} = ${service_name} ]] && [[  $pkg = "DBM" ]]; then
      rm -rf ${WORKSPACE}/tmpDir/${service_name}/images/*.tar
    fi
  done
  
  rm -rf ${WORKSPACE}/svc/${service}
  
  tempDirList=`ls ${WORKSPACE}/tmpDir/${service_name} | xargs`
  for dir in "${tempDirList[@]}"
  do
    if [ -d ${WORKSPACE}/tmpDir/${service_name}/images ]; then
      cnt=`ls -lh  ${WORKSPACE}/tmpDir/${service_name}/images | grep ".tar$" | wc -l`
      if [ $cnt -ge 1 ]; then
        mv ${WORKSPACE}/tmpDir/${service_name}/images/*.tar ${WORKSPACE}/solution/images
      else
        echo Notice: no tar file in package ${service}
      fi
      
      cnt=`ls ${WORKSPACE}/tmpDir/${service_name}/images | grep -v ".tar$" | wc -l`
      if [ $cnt -ge 1 ]; then
        imgDirs=`ls ${WORKSPACE}/tmpDir/${service_name}/images | grep -v ".tar$"`
        for imgDir in ${imgDirs}
        do
          if [ -d ${WORKSPACE}/tmpDir/${service_name}/images/${imgDir} ]; then
            rm -rf ${WORKSPACE}/solution/images/${imgDir}
            mv ${WORKSPACE}/tmpDir/${service_name}/images/${imgDir} ${WORKSPACE}/solution/images
          fi
        done
      fi
      
    else
      echo "images not found for ${service_name}"
    fi
    
    if [ -d ${WORKSPACE}/tmpDir/${service_name}/charts ]; then
      cnt=`ls -lh  ${WORKSPACE}/tmpDir/${service_name}/charts |grep ".tgz$" | wc -l`
      if [ $cnt -ge 1 ]; then
        mv ${WORKSPACE}/tmpDir/${service_name}/charts/*.tgz ${WORKSPACE}/solution/charts
      fi
    else
      echo "charts not found for ${service_name}"
    fi
    
    if [ -d ${WORKSPACE}/tmpDir/${service_name}/blueprints ]; then
      mkdir -p ${WORKSPACE}/solution/blueprints/${service_name}
      cnt=`ls -lh  ${WORKSPACE}/tmpDir/${service_name}/blueprints | grep .yaml | wc -l`
      if [ $cnt -ge 1 ]; then
        mv ${WORKSPACE}/tmpDir/${service_name}/blueprints/*.yaml ${WORKSPACE}/solution/blueprints/${service_name}
      fi
    else
      echo "blueprints not found for ${service_name}"
    fi
    
    if [ -d ${WORKSPACE}/tmpDir/${service_name}/packages ]; then
      mv ${WORKSPACE}/tmpDir/${service_name}/packages/* ${WORKSPACE}/solution/packages
    fi
  done

done


# step 4. replace blueprint
rm -rf ${WORKSPACE}/solution/blueprints/*.yaml

mv ${WORKSPACE}/solution/bootstrap/blueprints/* ${WORKSPACE}/solution/blueprints
rmdir ${WORKSPACE}/solution/bootstrap/blueprints

rm -rf ${WORKSPACE}/solution/blueprints/blueprint.yaml
rm -rf ${WORKSPACE}/solution/blueprints/blueprint-om.yaml

wget http://10.162.197.72:8090/CI_config/common/blueprint-base.yaml -O ${WORKSPACE}/solution/blueprints/blueprint.yaml 2>/dev/null
wget http://10.162.197.72:8090/CI_config/common/blueprint-om-base.yaml -O ${WORKSPACE}/solution/blueprints/blueprint-om.yaml 2>/dev/null

rm -rf ${WORKSPACE}/solution/blueprints/MySQL



if [ ! -d ${dstPOMDir} ]; then
    mkdir -p ${dstPOMDir}
fi

# save packages
if [ -f ${dstPOMDir}/${solution_name_ver}.zip ]; then
  rm -rf ${dstPOMDir}/${solution_name_ver}.zip
fi

rm -rf ${dstPOMDir}/../*.zip
cd ${WORKSPACE}/solution

#step 5. modify default rights.
  # 脚本增加权限不大于750
find . -name "*.sh" | xargs chmod 750
#find . -name "*.py" | xargs chmod 750
  # 配置文件和json文件不大于640
find . -name "*.conf" | xargs chmod 600
find . -name "*.json" | xargs chmod 600
find . -name "*.yaml" | xargs chmod 600
find . -name "*.xml" | xargs chmod 600
  # sql语句权限不大于640
#find . -name "*.sql" | xargs chmod 640
  # 压缩包文件权限不大于640
find . -name "*.zip" | xargs chmod 640
find . -name "*.tar.gz" | xargs chmod 640
find . -name "*.tgz" | xargs chmod 640
find . -name "*.tar" | xargs chmod 640

  # 特殊脚本文件权限不大于750
chmod 750 ${WORKSPACE}/solution/bootstrap/bin/*
chmod 640 ${WORKSPACE}/solution/bootstrap/conf/POM.version

  # 文件夹权限不大于750
find . -type d | xargs chmod 750

#证书文件夹700
chmod 700 ${WORKSPACE}/solution/bootstrap/cert ${WORKSPACE}/solution/bootstrap/userkey
chmod 600 ${WORKSPACE}/solution/bootstrap/cert/* ${WORKSPACE}/solution/bootstrap/userkey/*

# step 6. zip package

zip -r ${dstPOMDir}/${solution_name_ver}.zip ./*

#rm -rf ${WORKSPACE}/solution/*
cp ${dstPOMDir}/${solution_name_ver}.zip ${dstPOMDir}/..

####################将软件包上传到CloudArtifact 软件仓库####################
cd ${WORKSPACE}
fileDir=${dstPOMDir}/${solution_name_ver}.zip

echo "buildType="$buildType>uploadEnv.list
echo "ServiceName=FsPOM">>uploadEnv.list
echo "SERVICE_NAME=FsPOM">>uploadEnv.list
echo "Version="$Version>>uploadEnv.list
echo "SERVICE_VERSION="$Version>>uploadEnv.list
echo "isRelease="$isRelease>>uploadEnv.list
echo "releaseVersion="$releaseVersion>>uploadEnv.list
echo "RELEASE_VERSION="$releaseVersion>>uploadEnv.list
echo "fileDir="${fileDir}>>uploadEnv.list
