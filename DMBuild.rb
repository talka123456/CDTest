require 'xcodeproj'
require 'pathname'
require 'rugged'

CMD_PlistBuddy=`/usr/libexec/PlistBuddy`.chomp
CMD_Xcodebuild=`which xcodebuild`.chomp
CMD_Security=`which security`.chomp
CMD_Lipo=`which lipo`.chomp
CMD_Codesign=`which codesign`.chomp
CMD_Base64=`which base64`.chomp

DM_Ruby_WorkPath=`pwd`.chomp
DM_MobileProvision_Path = "#{ENV["HOME"]}/Library/MobileDevice/Provisioning Profiles"

# ------------------------------ 工具函数 ------------------------------ 
def dm_logit(log)
    printf "#{log}\n\r"
end

def dm_success(log)
    printf "\033[32m【DMBuildShell】#{log}\n\r\033[0m"
end

def dm_errorExit(log)
    printf "\033[31m【DMBuildShell】#{log}\n\r\033[0m"
    exit
end

def dm_warning(log)
    printf "\033[33m【DMBuildShell】#{log}\n\r\033[0m"
end

def
    dm_tipLogit(log)
    printf "\033[35m【DMBuildShell】#{log}\n\r\033[0m"
end

def dm_getRelativePathToFile(absolute, file)
    file = Pathname.new("#{file}")
    absolute = Pathname.new("#{absolute}")
    return absolute.relative_path_from(file).to_s.chomp
end

# -------------------------------- git 相关功能函数 --------------------------------

# 分支-branch 版本-version 默认-auto 构建目标-target 配置-configuration 是否自动上传-shouldUp

def dm_initGitRuggedRepo()
    repo = Rugged::Repository.new("#{DM_Ruby_WorkPath}/.git")
    if repo.nil?
        dm_errorExit "获取git 数据失败, 请检查#{DM_Ruby_WorkPath} 目录下的.git文件"
    end
    return repo;
end

def dm_checkBranchIfNessary(branch, repo)
    # 首先校验当前的分支数据

    ## 获取当前分支名称 判断是否需要切换

    ## 获取当前分支 是否clear
    ### git add & git  commit 
    current = repo.head
    dm_logit current.name
    # if current.name != branch

    #     # 切换分支
    # end
end
# -------------------------------- 项目相关功能函数 --------------------------------

# 构建工具 xcode版本
def dm_getXcodeVersion
    version = `#{CMD_Xcodebuild} -version | head -1 | cut -d ' ' -f 2`
    return version.chomp
end

def dm_findXcodeproj
    xcodeproj = `find #{DM_Ruby_WorkPath} -maxdepth 1 -type d -iname "*.xcodeproj"`
    return xcodeproj
end

def dm_findXcworkspace
    xcworkspace = `find #{DM_Ruby_WorkPath} -maxdepth 1 -type d -iname "*.xcworkspace"`
    return xcworkspace
end

def dm_findPodfile
    podfile = `find #{DM_Ruby_WorkPath} -maxdepth 1 -iname "Podfile"`
    return podfile
end

# --------------------------- 配置文件和证书 功能函数 ---------------------------
# def dm_getProvisionFileTeamID(provisionfile)
#     # 判断是否为文件
#     unless File.file?(provisionfile)
#         exit
#     end
#     provisonfileTeamID=`#{CMD_PlistBuddy} -c 'Print :Entitlements:com.apple.developer.team-identifier' /dev/stdin <<< $(#{CMD_Security} cms -D -i "#{provisionFile}" 2>/dev/null)`
# 	return provisonfileTeamID
# end

# def dm_getProfileType(provisionfile)
# end

# def dmGetProfileBundleID(provisionfile)
#     local applicationIdentifier=`#{CMD_PlistBuddy} -c 'Print :Entitlements:application-identifier' /dev/stdin <<< "$(#{CMD_Security} cms -D -i "#{provisionfile}" 2>/dev/null)`
# 	if applicationIdentifier.empty?
#         dm_errorExit "获取#{provisionfile}中的application-identifier字段失败"
#     end

# 	##截取bundle id,这种截取方法，有一点不太好的就是：当applicationIdentifier的值包含：*时候，会截取失败,如：applicationIdentifier=6789.*
# 	local bundleId=`#{applicationIdentifier}#*.`
# 	return bundleId
# end

# def dm_matchMobileProvisionFile(channel, bundleID)

#     unless File.directory?(DM_MobileProvision_Path)
#         dm_errorExit "#{DM_MobileProvision_Path} 路径不是目录, 请检查MobileProvision路径"
#     end

#     provisionFile = ''
#     maxExpireTimestamp = 0
#     Dir.foreach(DM_MobileProvision_Path) do |file|
#         if File.extname(file) == ".mobileprovision"
#             bundleIDFromProvisionFile = dmGetProfileBundleID(file)
#             # 截取最后两个字符, 用于判断是否为通配符
#             wildcard = bundleIDFromProvisionFile[-2..-1]

#             orginPrefix = `echo ${#{bundleIdFromProvisionFile}%.*}`
#             targetPrefix = `echo "${#{bundleID}%.*}"`

#             # 匹配Bundle ID
#             if bundleID == bundleIDFromProvisionFile || (wildcard == ".*" && orginPrefix == targetPrefix)
#                 # 匹配Channel 
#                 profileType = dmGetProvisionProfileType(file)
#                 if profileType == channel
#                     # 过期时间
#                     timestamp = dmGetProvisionFileExpireTimestamp(file)

#                 end
#             end
#         end
#     end
# end

# -------------------------------------------- 核心逻辑--------------------------

# =========================== 切换分支
repo = dm_initGitRuggedRepo()
dm_checkBranchIfNessary("main2", repo)

exit

# =========================== 解析xcodeproj文件
# 查找xcodeproj文件
absoluteXcodeProj = dm_findXcodeproj().chomp
# 相对路径, Xcodeproj库使用
relativeXcodeproj = dm_getRelativePathToFile(absoluteXcodeProj, "#{DM_Ruby_WorkPath}")
project_path = relativeXcodeproj

if project_path.nil? || project_path.empty?
    dm_errorExit "无法找到.xcodeproj工程文件, 请检查"
    exit
end

# =========================== 当前的可用target 供用户选择
dm_targets = Array.new
dm_target_configuretions = Array.new
project = Xcodeproj::Project.open(project_path)
project.targets.each do |t|
    dm_targets.push(t.name)
end

dm_tipLogit "请选择需求构建的Target索引:"
dm_tip_targets = ""
dm_targets.each do |target|
    dm_target_index = dm_targets.index(target)
    dm_tip_targets = dm_tip_targets + " #{dm_target_index}. #{target}\r\n"
end

dm_logit dm_tip_targets
dm_userselected = gets.strip

dm_retry = true
while dm_retry do
    if dm_userselected.empty? || Integer(dm_userselected) < 0 || Integer(dm_userselected) >= dm_targets.size
        dm_warning "选择的target索引错误, 请重新选择"
        dm_userselected = gets.strip
    else
        dm_retry = false
    end
end

dm_userselected_target = dm_targets[Integer(dm_userselected)]
dm_logit "你选择的Target为: #{dm_userselected_target}"

# =========================== 获取选择target包含的可选配置 configuration 供用户选择
dm_configurations = Array.new
project.targets.each do |t|
    if t.name === dm_userselected_target
        t.build_configurations.each do |config|
            dm_configurations.push(config.name)
        end
    end
end

dm_tipLogit "请选择需求构建的#{dm_userselected_target}项目的编译环境索引:"
dm_tip_configurations = ""
dm_configurations.each do |config|
    dm_configuration_index = dm_configurations.index(config)
    dm_tip_configurations = dm_tip_configurations + " #{dm_configuration_index}. #{config}\r\n"
end

dm_logit dm_tip_configurations
dm_userselected = gets.strip

dm_retry = true
while dm_retry do
    if dm_userselected.empty? || Integer(dm_userselected) < 0 || Integer(dm_userselected) >= dm_targets.size
        dm_warning "选择的configuration索引错误, 请重新选择"
        dm_userselected = gets.strip
    else
        dm_retry = false
    end
end

dm_userselected_configuration = dm_configurations[Integer(dm_userselected)]

dm_logit "你选择的编译环境为: #{dm_userselected_configuration}"

# =========================== 获取build channel =====================
dm_build_channel = "enterprise"

# =========================== 获取target 和 configuration相关的工程信息

# bundle id
dm_userselected_bundleID = ""

# info.plist 路径
dm_userselected_infoDir = ""
project.targets.each do |t|
    if t.name === dm_userselected_target
        t.build_configurations.each do |config|
            if config.name === dm_userselected_configuration
                dm_userselected_bundleID = config.resolve_build_setting("PRODUCT_BUNDLE_IDENTIFIER")
                dm_userselected_infoDir = config.resolve_build_setting("INFOPLIST_FILE")
            end
        end
    end
end

# 查找是否包含Podfile 文件, 存在需要构建前执行pod install
dm_xcodeworkspace = dm_findXcworkspace()
dm_podfile = dm_findPodfile()

# 未搜索到xcodeworkspace文件, 但是存在podfile时 手动赋值workspace路径, 后续fastlane需要使用
if dm_xcodeworkspace.empty? && !dm_podfile.empty?
    # 使用项目名手动赋值, 此处不进行pod install, 执行fastlane 逻辑时执行
    dm_object_name = project.root_object.name
    dm_xcodeworkspace = "#{dm_object_name}.xcworkspace"
end

dm_success dm_userselected_target
dm_success dm_userselected_configuration
dm_success dm_xcodeworkspace
dm_success dm_userselected_bundleID
dm_success dm_userselected_infoDir
dm_success "xcode版本号为: #{dm_getXcodeVersion()}"

# =========================== 证书 和 pp文件信息校验(TODO:cf 功能暂未开发)
# dm_mobileprovision_file = dm_matchMobileProvisionFile(dm_build_channel, dm_userselected_bundleID)
# if dm_mobileprovision_file.empty?
#     dm_errorExit "不存在Bundle Id 为 #{dm_userselected_bundleID} 且分发渠道为#{dm_build_channel}的描述文件，请检查#{DM_MobileProvision_Path}目录是否存在对应描述文件"
# end