fastlane documentation
================
# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```
xcode-select --install
```

Install _fastlane_ using
```
[sudo] gem install fastlane -NV
```
or alternatively using `brew install fastlane`

# Available Actions
## iOS
### ios dm_buildApp
```
fastlane ios dm_buildApp
```
build app interface

op 支持参数： shouldUp: 是否需要上传true/false, 默认为true

op 支持参数： version: 版本(可选), 默认使用工程中的版本号

op 支持参数： method: method 配置[app-store, ad-hoc, enterprise, development], 默认为enterprise

op 支持参数:  scheme : 构建目标

op 支持参数:  configuration : 构建环境 默认Debug

op 支持参数: message: 提交到fir.im的消息内容

----

This README.md is auto-generated and will be re-generated every time [fastlane](https://fastlane.tools) is run.
More information about fastlane can be found on [fastlane.tools](https://fastlane.tools).
The documentation of fastlane can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
