#!/bin/bash

# 命令路径
CMD_PlistBuddy="/usr/libexec/PlistBuddy"
CMD_Xcodebuild=$(which xcodebuild)
CMD_Security=$(which security)
CMD_Lipo=$(which lipo)
CMD_Codesign=$(which codesign)

##脚本工作目录
Shell_Work_Path=$(pwd)

### 自动更新版本号,默认为NO
UNLOCK_KEYCHAIN_PWD=''
PROVISION_DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"

## 日志格式化输出
function logit() {
    echo -e "\033[32m [IPABuildShell] \033[0m $@" 

}

## 日志格式化输出
function errorExit(){

    echo -e "\033[31m【IPABuildShell】$@ \033[0m"
    exit 1
}

## 日志格式化输出
function warning(){

    echo -e "\033[33m【警告】$@ \033[0m"
}

##获取Xcode 版本
function getXcodeVersion() {
	local xcodeVersion=`$CMD_Xcodebuild -version | head -1 | cut -d " " -f 2`
	echo $xcodeVersion
}

## 获取workspace的项目路径列表
function getAllXcprojPathFromWorkspace() {
	local xcworkspace=$1;
	local xcworkspacedataFile="$xcworkspace/contents.xcworkspacedata";
	if [[ ! -f "$xcworkspacedataFile" ]]; then
		echo "xcworkspace 文件不存在";
		exit 1;
	fi
	local list=($(grep "location =" "$xcworkspacedataFile" | cut -d "\"" -f2 | cut -d ":" -f2))
	## 补充完整路径
	local completePathList=()
	for xcproj in ${list[*]}; do
		local path="${xcworkspace}/../${xcproj}"
		## 数组追加元素括号里面第一个参数不能用双引号，否则会多出一个空格
		completePathList=(${completePathList[*]} "$path")

	done
	echo "${completePathList[*]}"
}

##查找xcworkspace工程启动文件
function findXcworkspace() {

	#-d:如果文件存在存在并且是目录则为真, -f:如果文件存在并且未普通文件则为真
	local xcworkspace=$(find "$Shell_Work_Path" -maxdepth 1  -type d -iname "*.xcworkspace")
	if [[ -d "$xcworkspace" ]] || [[ -f "${xcworkspace}/contents.xcworkspacedata" ]]; then
		echo $xcworkspace
	fi
}

## 获取xcproj的所有target
## 比分数组元素本身带有空格，所以采用字符串用“;”作为分隔符，而不是用数组。
function getAllTargetsInfoFromXcprojList() {
	## 转换成数组
	local xcprojList=$1

	## 因在mac 系统下 在for循环中无法使用map ，所以使用数组来代替，元素格式为 targetId:targetName:xcprojPath
	local wrapXcprojListStr='' ##
	## 获取每个子工程的target
	for (( i = 0; i < ${#xcprojList[*]}; i++ )); do
		local xcprojPath=${xcprojList[i]};
		local pbxprojPath="${xcprojPath}/project.pbxproj"
		if [[ -f "$pbxprojPath" ]]; then
			# echo "$pbxprojPath"
			local rootObject=$($CMD_PlistBuddy -c "Print :rootObject" "$pbxprojPath")
			local targetIdList=$($CMD_PlistBuddy -c "Print :objects:${rootObject}:targets" "$pbxprojPath" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
			#括号用于初始化数组,例如arr=(1,2,3)
			local targetIds=($(echo $targetIdList));
			for targetId in ${targetIds[*]}; do
				local targetName=$($CMD_PlistBuddy -c "Print :objects:$targetId:name" "$pbxprojPath")
				local info="${targetId}:${targetName}:${xcprojPath}"
				if [[ "$wrapXcprojListStr" == '' ]]; then
					wrapXcprojListStr="$info";
				else
					wrapXcprojListStr="${wrapXcprojListStr};${info}";

				fi
			done
		fi
	done
	echo "$wrapXcprojListStr"
}

function getTargetInfoValue(){

	local targetInfo="$1"
	local key="$2"
	if [[ "$targetInfo" == "" ]] || [[ "$key" == "" ]]; then
		errorExit "getTargetInfoValue 参数不能为空"
	fi

	## 更换数组分隔符
	OLD_IFS="$IFS"
	IFS=":"
	local arr=($targetInfo)
	IFS="$OLD_IFS"
	if [[ ${#arr[@]} -lt 3 ]]; then
		errorExit "getTargetInfoValue 函数出错"
	fi
	local value=''
	if [[ "$key"  == "id" ]]; then
		value=${arr[0]}
	elif [[ "$key" == "name" ]]; then
		value=${arr[1]}
	elif [[ "$key" == "xcproj" ]]; then
		value=${arr[2]}
	fi
	echo "$value"
}

## 获取配置ID,主要是后续用了获取bundle id
function getConfigurationIds() {

	##配置模式：Debug 或 Release
	local targetId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
  	local buildConfigurationListId=$($CMD_PlistBuddy -c "Print :objects:$targetId:buildConfigurationList" "$pbxproj")
  	local buildConfigurationList=$($CMD_PlistBuddy -c "Print :objects:$buildConfigurationListId:buildConfigurations" "$pbxproj" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
  	##数组中存放的分别是release和debug对应的id
  	local configurationTypeIds=$(echo $buildConfigurationList)
  	echo $configurationTypeIds

}

function getConfigurationIdWithType(){

	local configrationType=$3
	local targetId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi

	local configurationTypeIds=$(getConfigurationIds "$1" $targetId)
	for id in ${configurationTypeIds[@]}; do
	local name=$($CMD_PlistBuddy -c "Print :objects:$id:name" "$pbxproj")
	if [[ "$configrationType" == "$name" ]]; then
		echo $id
	fi
	done
}

## 获取bundle Id,分为Releae和Debug
function getProjectBundleId()
{	
	local configurationId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi

    
    local bundleId=""
	# local bundleId=$($CMD_PlistBuddy -c "Print :objects:$configurationId:buildSettings:PRODUCT_BUNDLE_IDENTIFIER" "$pbxproj" | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//')
	echo $bundleId
}

function getInfoPlistFile()
{
	configurationId=$2
	local pbxproj=$1/project.pbxproj
	if [[ ! -f "$pbxproj" ]]; then
		exit 1
	fi
   local  infoPlistFileName=$($CMD_PlistBuddy -c "Print :objects:$configurationId:buildSettings:INFOPLIST_FILE" "$pbxproj" )
   ## 替换$(SRCROOT)为.
   infoPlistFileName=${infoPlistFileName//\$(SRCROOT)/.}
	  ### 完整路径
	infoPlistFilePath="$1/../$infoPlistFileName"
	echo $infoPlistFilePath
}

# 校验证书签名合法性
function checkCodeSignIdentityValid()
{
	local codeSignIdentity=$1
	local content=$($CMD_Security find-identity -v -p codesigning | grep "$codeSignIdentity")
	echo "$content"
}

##匹配描述文件
function matchMobileProvisionFile()
{	

	##分发渠道
	local channel=$1
	local appBundleId=$2
	##描述文件目录
	local mobileProvisionFileDir=$3
	if [[ ! -d "$mobileProvisionFileDir" ]]; then
		exit 1
	fi
	##遍历
	local provisionFile=''
	local maxExpireTimestmap=0

	for file in "${mobileProvisionFileDir}"/*.mobileprovision; do
		local bundleIdFromProvisionFile=$(getProfileBundleId "$file")
		local wildcard=${bundleIdFromProvisionFile:0-2} ##从右边取2个字符串




		local orginPrefix=$(echo ${bundleIdFromProvisionFile%.*})
		local targetPrefix=$(echo "${appBundleId%.*}")


		if [[ "$appBundleId" == "$bundleIdFromProvisionFile"  || (( "$wildcard" == '.*' &&  "$orginPrefix" == "$targetPrefix" )) ]]  ; then

			# echo "$bundleIdFromProvisionFile ： $appBundleId ，$orginPrefix : $targetPrefix "
			local profileType=$(getProfileType "$file")
			if [[ "$profileType" == "$channel" ]]; then
				local timestmap=$(getProvisionfileExpireTimestmap "$file")
				## 匹配到有效天数最大的描述文件
				if [[ $timestmap -gt $maxExpireTimestmap ]]; then
					provisionFile=$file
					maxExpireTimestmap=$timestmap
				fi
			fi
		fi
	done
	echo $provisionFile
}



function getProfileBundleId()
{
	local profile=$1
	# 通过security cms -D -i XXX.mobileprovision可以解析.mobileprovision文件和证书
	local applicationIdentifier=$($CMD_PlistBuddy -c 'Print :Entitlements:application-identifier' /dev/stdin <<< "$($CMD_Security cms -D -i "$profile" 2>/dev/null )")
	if [[ $? -ne 0 ]]; then
		exit 1;
	fi
	##截取bundle id,这种截取方法，有一点不太好的就是：当applicationIdentifier的值包含：*时候，会截取失败,如：applicationIdentifier=6789.*
	local bundleId=${applicationIdentifier#*.}
	echo $bundleId
}

function getProfileInfo(){

			if [[ ! -f "$1" ]]; then
				errorExit "指定描述文件不存在!"
			fi

			provisionFileTeamID=$(getProvisionfileTeamID "$1")
			provisionFileType=$(getProfileType "$1")
			channelName=$(getProfileTypeCNName $provisionFileType)
			provisionFileName=$(getProvisionfileName "$1")
			provisionFileBundleID=$(getProfileBundleId "$1")
			provisionfileTeamName=$(getProvisionfileTeamName "$1")
			provisionFileUUID=$(getProvisionfileUUID "$1")

  			provisionfileCreateTimestmap=$(getProvisionfileCreateTimestmap "$1")
  			provisionfileCreateTime=$(date -r `expr $provisionfileCreateTimestmap `  "+%Y年%m月%d" )
  			provisionfileExpireTimestmap=$(getProvisionfileExpireTimestmap "$1")
  			provisionfileExpireTime=$(date -r `expr $provisionfileExpireTimestmap `  "+%Y年%m月%d" )
			provisionFileExpirationDays=$(getExpiretionDays "$provisionfileExpireTimestmap")

			provisionfileCodeSign=$(getProvisionCodeSignIdentity "$1")
			provisionfileCodeSignSerial=$(getProvisionCodeSignSerial "$1")

			provisionCodeSignCreateTimestmap=$(getProvisionCodeSignCreateTimestamp "$1")
			provisionCodeSignCreateTime=$(date -r `expr $provisionCodeSignCreateTimestmap `  "+%Y年%m月%d" )
			provisionCodeSignExpireTimestamp=$(getProvisionCodeSignExpireTimestamp "$1")
			provisionCodeSignExpireTime=$(date -r `expr $provisionCodeSignExpireTimestamp + 86400`  "+%Y年%m月%d" )
			provisionCodesignExpirationDays=$(getExpiretionDays "$provisionCodeSignExpireTimestamp")
			

			logit "【描述文件】名字：$provisionFileName "
			logit "【描述文件】类型：${provisionFileType}（${channelName}）"
			logit "【描述文件】TeamID：$provisionFileTeamID "
			logit "【描述文件】Team Name：$provisionfileTeamName "
			logit "【描述文件】BundleID：$provisionFileBundleID "
			logit "【描述文件】UUID：$provisionFileUUID "
			logit "【描述文件】创建时间：$provisionfileCreateTime "
			logit "【描述文件】过期时间：$provisionfileExpireTime "
			logit "【描述文件】有效天数：$provisionFileExpirationDays "
			logit "【描述文件】使用的证书签名ID：[${provisionfileCodeSign}]"
			logit "【描述文件】使用的证书序列号：$provisionfileCodeSignSerial"
			logit "【描述文件】使用的证书创建时间：$provisionCodeSignCreateTime"
			logit "【描述文件】使用的证书过期时间：$provisionCodeSignExpireTime"
			logit "【描述文件】使用的证书有效天数：$provisionCodesignExpirationDays "

			if [[ $provisionFileExpirationDays -lt 0 ]]; then
				errorExit "描述文件:${provisionFileName} 已过期，请更新描述文件!"
			fi
			if [[ $provisionCodesignExpirationDays -lt 0 ]]; then
				errorExit "证书:${provisionfileCodeSign} 已过期，请更新证书!"
			fi
}


##获取描述文件类型
function getProfileType()
{
	local profile=$1
	local profileType=''
	if [[ ! -f "$profile" ]]; then
		exit 1
	fi
	##判断是否存在key:ProvisionedDevices
	local haveKey=$($CMD_Security cms -D -i "$profile" 2>/dev/null | sed -e '/Array {/d' -e '/}/d' -e 's/^[ \t]*//' | grep ProvisionedDevices)
	if [[ "$haveKey" ]]; then
		local getTaskAllow=$($CMD_PlistBuddy -c 'Print :Entitlements:get-task-allow' /dev/stdin <<< $($CMD_Security cms -D -i "$profile" 2>/dev/null ) )
		if [[ $getTaskAllow == true ]]; then
			profileType='development'
		else
			profileType='ad-hoc'
		fi
	else

		local haveKeyProvisionsAllDevices=$($CMD_Security cms -D -i "$profile" 2>/dev/null | grep ProvisionsAllDevices)
		if [[ "$haveKeyProvisionsAllDevices" != '' ]]; then
			provisionsAllDevices=$($CMD_PlistBuddy -c 'Print :ProvisionsAllDevices' /dev/stdin <<< "$($CMD_Security cms -D -i "$profile" 2>/dev/null)" )
			if [[ $provisionsAllDevices == true ]]; then
				profileType='enterprise'
			else
				profileType='app-store'
			fi
		else
			profileType='app-store'
		fi
	fi
	echo $profileType
}

## 获取profile type的中文名字
function getProfileTypeCNName()
{
    local profileType=$1
    local profileTypeName
    if [[ "$profileType" == 'app-store' ]]; then
        profileTypeName='商店分发'
    elif [[ "$profileType" == 'enterprise' ]]; then
        profileTypeName='企业分发'
	elif [[ "$profileType" == 'ad-hoc' ]]; then
        profileTypeName='内部测试(ad-hoc)'
    else
        profileTypeName='内部测试'
    fi
    echo $profileTypeName

}

###########################################核心逻辑#####################################################

### Xcode版本
xcVersion=$(getXcodeVersion)
if [[ ! "$xcVersion" ]]; then
	errorExit "获取当前XcodeVersion失败"
fi
logit "【构建信息】Xcode版本：$xcVersion"


## 获取xcproj 工程列表
xcworkspace=$(findXcworkspace)

xcprojPathList=()
if [[ "$xcworkspace" ]]; then
	
	logit "【构建信息】项目结构：多工程协同(workspace)"

	##  外括号作用是转变为数组
	xcprojPathList=($(getAllXcprojPathFromWorkspace "$xcworkspace"))
	num=${#xcprojPathList[@]} ##数组长度 
	if [[ $num -gt 1 ]]; then
		i=0
		for xcproj in ${xcprojPathList[*]}; do
			# 算数运算命令 expr 计算并输出结果, 索引加1
			i=$(expr $i + 1)
			# ${##*/}:字符串模式匹配 移除最后一个/左边所有字符
			logit "【构建信息】工程${i}：${xcproj##*/}"
		done
	fi

else
	## 查找xcodeproj 文件
	logit "【构建信息】项目结构：单工程"
	xcodeprojPath=$(findXcodeproj)
	if [[ "$xcodeprojPath" ]]; then
		logit "【构建信息】工程路径:$xcodeprojPath"
	else
		errorExit "当前目录不存在.xcworkspace或.xcodeproj工程文件，请在项目工程目录下执行脚本$(basename $0)"
	fi
	xcprojPathList=("$xcodeprojPath")
fi


## 需要构建的xcprojPath列表,即除去Pods.xcodeproj之外的
buildXcprojPathList=()

for (( i = 0; i < ${#xcprojPathList[*]}; i++ ))
do
	path=${xcprojPathList[i]};
	if [[ "${path##*/}" == "Pods.xcodeproj" ]]
	then
		continue;
	fi

	## 数组追加元素括号里面第一个参数不能用双引号，否则会多出一个空格
	buildXcprojPathList=(${buildXcprojPathList[*]} "$path")
done

logit "【构建信息】可构建的工程数量（不含Pods）:${#buildXcprojPathList[*]}"


## 获取可构建的工程列表的所有target
targetsInfoListStr=$(getAllTargetsInfoFromXcprojList "${buildXcprojPathList[*]}")

## 设置数组分隔符号为分号
OLD_IFS="$IFS" ##记录当前分隔符号
IFS=";"
targetsInfoList=($targetsInfoListStr)

logit "【构建信息】可构建的Target数量（不含Pods）:${#targetsInfoList[*]}"

i=1
for targetInfo in ${targetsInfoList[*]}; do
	tId=$(getTargetInfoValue "$targetInfo" "id")
	tName=$(getTargetInfoValue "$targetInfo" "name")
	logit "【构建信息】可构建Target${i}：${tName}"
	i=$(expr $i + 1 )
done

# TODO:让用户选择构建的 target 目标
BUILD_TARGET="Moments_2"

IFS="$OLD_IFS" ##还原

##获取构建的targetName和targetId 和构建的xcodeprojPath
targetName=''
targetId=''
xcodeprojPath=''
if [[ "$BUILD_TARGET" ]]; then
	for targetInfo in ${targetsInfoList[*]}; do
		tId=$(getTargetInfoValue "$targetInfo" "id")
		tName=$(getTargetInfoValue "$targetInfo" "name")
		path=$(getTargetInfoValue "$targetInfo" "xcproj")
		if [[ "$tName" == "$BUILD_TARGET" ]]; then
			targetName="$tName"
			targetId="$tId"
			xcodeprojPath="$path"
			break;
		fi

	done
else
		## 默认选择第一个target
	targetInfo=${targetsInfoList[0]}
	targetId=$(getTargetInfoValue "$targetInfo" "id")
	targetName=$(getTargetInfoValue "$targetInfo" "name")
	xcodeprojPath=$(getTargetInfoValue "$targetInfo" "xcproj")
fi

logit "【构建信息】构建Target：${targetName}（${targetId}）"

if [[ ! "targetName" ]] || [[ ! "targetId" ]] || [[ ! "xcodeprojPath" ]]; then
	errorExit "获取构建信息失败!"
fi

##获取构配置类型的ID （Release和Debug分别对应不同的ID）
configurationTypeIds=$(getConfigurationIds "$xcodeprojPath" "$targetId")
if [[ ! "$configurationTypeIds" ]]; then
	errorExit "获取配置模式(Release和Debug)Id列表失败"
fi

dm_pbxproj=$xcodeprojPath/project.pbxproj
for id in ${configurationTypeIds[@]}; do
	name=$($CMD_PlistBuddy -c "Print :objects:$id:name" "$dm_pbxproj")
    logit "【构建信息】配置模式: $name"
done

# # TODO: 允许用户选择构建配置
CONFIGRATION_TYPE="Internal"

## 获取当前构建的配置模式ID
configurationId=$(getConfigurationIdWithType "$xcodeprojPath" "$targetId" "$CONFIGRATION_TYPE")
if [[ ! "$configurationId" ]]; then
	errorExit "获取${CONFIGRATION_TYPE}配置模式Id失败"
fi
logit "【构建信息】配置模式：$CONFIGRATION_TYPE"

bundleIdLong=$($CMD_PlistBuddy -c "Print :objects:$configurationId:buildSettings" "$dm_pbxproj")
warning "啊哈哈哈哈哈哈: ${bundleIdLong}"

## 获取工程中的Bundle Id
# projectBundleId=$(getProjectBundleId "$xcodeprojPath" "$configurationId")
# if [[ ! "$projectBundleId" ]] ; then
# 	errorExit "获取项目的Bundle Id失败"
# fi

# logit "【构建信息】Bundle Id：$projectBundleId"
# infoPlistFile=$(getInfoPlistFile "$xcodeprojPath" "$configurationId")
# if [[ ! -f "$infoPlistFile" ]]; then
# 	errorExit "获取infoPlist文件失败"
# fi
# logit "【构建信息】InfoPlist 文件：$infoPlistFile"

##检查openssl
# checkOpenssl

# logit "【构建信息】进行描述文件匹配..."
# # 匹配描述文件
# provisionFile=$(matchMobileProvisionFile "$CHANNEL" "$projectBundleId" "$PROVISION_DIR")
# if [[ ! "$provisionFile" ]]; then
# 	errorExit "不存在Bundle Id 为 ${projectBundleId} 且分发渠道为${CHANNEL}的描述文件，请检查${PROVISION_DIR}目录是否存在对应描述文件"
# fi

# #导入描述文件
# open "$provisionFile"

# logit "【构建信息】匹配描述文件：$provisionFile"

# # 展示描述文件信息
# getProfileInfo "$provisionFile"

# # 获取签名
# codeSignIdentity=$(getProvisionCodeSignIdentity "$provisionFile")
# if [[ ! "$codeSignIdentity" ]]; then
# 	errorExit "获取描述文件签名失败! 描述文件:${provisionFile}"
# fi

# logit "【签名信息】匹配签名ID：【$codeSignIdentity"】

# result=$(checkCodeSignIdentityValid "$codeSignIdentity")
# if [[ ! "$result" ]]; then
# 	errorExit "签名ID:${codeSignIdentity}无效，请检查钥匙串是否导入对应的证书或脚本访问keychain权限不足，请使用-p参数指定密码 "
# fi

# if [[ $ONLYSHOWSIGN ]]; then
# 	exit;
# fi
