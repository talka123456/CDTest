require 'xcodeproj'

# 查找WorkSpace or project, 并获取路径

project_path = "Moments.xcodeproj"
project = Xcodeproj::Project.open(project_path)

project.targets.each do |t|
    if t.name === "Moments_2"
        t.build_configurations.each do |config|
            if config.name === "Internal"
                puts config.build_settings
            end
        end
    end
end

# 查找是否包含Podfile 文件, 存在需要构建前执行pod install

# 打印当前的可用target 供用户选择

# 打印当前target的configuration 供用户选择

# 获取target 和 configuration相关的工程信息, 

## info.plist文件路径
## Bundle ID
## 证书 和 pp文件信息