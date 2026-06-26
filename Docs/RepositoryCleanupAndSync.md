下面这版建议保存为 Docs/RepositoryCleanupAndSync.md，然后直接丢给 Codex 执行。重点是：先备份/打 tag，再清理无效文件，再合并当前功能分支，最后推送 GitHub。不要让 Codex 误删 Pods、工程配置或本地签名配置。

Codex 执行任务：阶段 2F - 本地仓库清理与 GitHub 全量同步

一、当前状态

当前项目：

WYM-HAGGI/GeometricWeather-iOS

当前本地项目路径：

/Users/haggi/Documents/几何天气-iOS

当前已经完成的关键阶段：

✅ 阶段 1：旧 iOS 项目已救活，可真机构建、安装、启动
✅ 阶段 2A：Open-Meteo 天气源已接入
✅ 阶段 2B：当前位置和详细地址展示已优化
✅ 阶段 2D：小时概览改为最近 24H，取消协同滚动
✅ 阶段 2E：深色模式可读性优化完成
✅ 当前版本日常使用体验已经比较稳定

当前最新有效提交：

619a2f01 step2e: improve dark mode readability

当前已知本地未提交项包括：

GeometricWeather.xcodeproj/project.pbxproj
GeometricWeather.xcodeproj/xcshareddata/xcschemes/GeometricWeather.xcscheme
.derivedData-17pm/
Pods/Pods.xcodeproj/xcshareddata/

历史报告中明确不应提交：

.DS_Store
Config/LocalConfig.xcconfig
.derivedData-17pm/
Pods/Pods.xcodeproj/xcshareddata/
真实 AMAP Key
个人签名证书
本地 DerivedData
个人设备 scheme 临时配置

现在目标：

1. 清理本地无效、无用、中间生成文件
2. 保留截止目前最新可用版本的必要构建配置
3. 确认仓库不包含真实密钥、个人证书、本地缓存
4. 将当前最新项目内容全量同步到 GitHub fork 仓库
5. 推送最新分支、必要 tag
6. 不破坏当前本地可构建状态

⸻

二、执行原则

请严格遵守：

1. 清理前必须先查看 git status
2. 清理前必须先创建安全 tag
3. 不要误删项目源代码
4. 不要误删必须纳入版本管理的 Xcode project 配置
5. 不要提交真实 API Key
6. 不要提交 Config/LocalConfig.xcconfig
7. 不要提交个人 Apple 签名配置
8. 不要提交 DerivedData
9. 不要提交 .DS_Store
10. 不要提交 Pods 内部生成的 xcshareddata
11. 不要强制 push，除非明确确认远端历史需要覆盖
12. 推送前必须完成构建验证

⸻

三、第一步：确认当前 Git 状态

请先执行：

cd /Users/haggi/Documents/几何天气-iOS
git status
git branch --show-current
git log --oneline --decorate -10
git remote -v

请输出：

1. 当前分支
2. 当前 HEAD commit
3. 当前未提交文件列表
4. origin 指向
5. 是否存在 upstream

⸻

四、第二步：创建当前稳定版本 tag

在任何清理动作前，先打稳定 tag：

git tag -a v0.3-openmeteo-stable -m "Stable Open-Meteo iOS build with location display, hourly 24H behavior, and dark readability fixes"

如果 tag 已存在，请不要覆盖，改用：

git tag -a v0.3.1-openmeteo-stable -m "Stable Open-Meteo iOS build with latest readability fixes"

然后确认：

git tag --list

⸻

五、第三步：处理当前未提交文件

1. 必须重点检查这些文件

当前存在这些未提交项：

GeometricWeather.xcodeproj/project.pbxproj
GeometricWeather.xcodeproj/xcshareddata/xcschemes/GeometricWeather.xcscheme
.derivedData-17pm/
Pods/Pods.xcodeproj/xcshareddata/

请逐个判断。

⸻

2. 关于 GeometricWeather.xcodeproj/project.pbxproj

这个文件很敏感。

请先执行：

git diff -- GeometricWeather.xcodeproj/project.pbxproj

判断是否属于必要修改。

如果 diff 仅包含以下内容：

个人签名 Team ID
个人设备
本地 DerivedData 路径
临时 scheme
Provisioning profile
Bundle identifier 临时测试值
CODE_SIGN_STYLE
DEVELOPMENT_TEAM
PROVISIONING_PROFILE

则不要提交，执行：

git restore GeometricWeather.xcodeproj/project.pbxproj

如果 diff 包含以下必要内容：

新增 Swift 文件纳入 Xcode target
新增资源文件纳入 target
新增 Build Phase
新增 Package / Framework 依赖
项目无法构建时必须保留的配置

则保留并准备提交。

注意：

如果本项目使用 Swift Package 目录自动纳入源码，则 Open-Meteo 新增文件可能不需要修改 pbxproj。
如果新增文件已经构建成功且 pbxproj diff 只是签名/设备信息，则不要提交 pbxproj。

⸻

3. 关于 GeometricWeather.xcodeproj/xcshareddata/xcschemes/GeometricWeather.xcscheme

请执行：

git diff -- GeometricWeather.xcodeproj/xcshareddata/xcschemes/GeometricWeather.xcscheme

如果只是：

个人设备
调试目标
本机环境变量
临时启动配置

则不要提交：

git restore GeometricWeather.xcodeproj/xcshareddata/xcschemes/GeometricWeather.xcscheme

如果是：

修复 CI / 通用构建必须的 scheme
共享 scheme 必须更新

则可保留，但要在报告中说明。

⸻

4. 关于 .derivedData-17pm/

这是本地构建产物，必须删除并加入忽略。

执行：

rm -rf .derivedData-17pm/

确保 .gitignore 包含：

.derivedData-*/
DerivedData/

如果没有，请添加。

⸻

5. 关于 Pods/Pods.xcodeproj/xcshareddata/

这是 CocoaPods 生成或本地 Xcode 共享数据。

优先不要提交。
如果它是未跟踪文件，删除：

rm -rf Pods/Pods.xcodeproj/xcshareddata/

如果它是已跟踪文件，请先检查：

git ls-files Pods/Pods.xcodeproj/xcshareddata/

如果未被跟踪，直接删除即可。
如果已被跟踪，不要贸然删除，先输出情况。

⸻

6. 关于 .DS_Store

执行：

find . -name ".DS_Store" -print

删除所有 .DS_Store：

find . -name ".DS_Store" -delete

确保 .gitignore 包含：

.DS_Store

如果之前 .DS_Store 已被跟踪，请执行：

git rm --cached .DS_Store

如果子目录也有被跟踪的 .DS_Store，逐个从 git index 移除：

git ls-files | grep ".DS_Store"

然后：

git ls-files | grep ".DS_Store" | xargs git rm --cached

⸻

六、第四步：完善 .gitignore

请检查 .gitignore，确保包含以下规则：

# macOS
.DS_Store
# Xcode
DerivedData/
.derivedData-*/
*.xcuserstate
*.xcuserdata/
xcuserdata/
# Local config / secrets
Config/LocalConfig.xcconfig
*.local.xcconfig
.env
.env.*
# Build products
build/
Build/
*.ipa
*.dSYM.zip
# SwiftPM
.swiftpm/
# CocoaPods generated local metadata
Pods/Pods.xcodeproj/xcuserdata/
Pods/Pods.xcodeproj/xcshareddata/

注意：

不要直接忽略整个 Pods/，除非当前仓库原本就不跟踪 Pods。
如果当前项目历史上已经跟踪 Pods 目录，为避免破坏现有构建，不要贸然移除整个 Pods。
只忽略 Pods 内部本地 metadata。

⸻

七、第五步：扫描敏感信息

推送前必须扫描是否有真实 Key 或证书。

请执行：

git grep -n "AMAP" || true
git grep -n "amap" || true
git grep -n "api_key" || true
git grep -n "apikey" || true
git grep -n "API_KEY" || true
git grep -n "SECRET" || true
git grep -n "PRIVATE" || true
git grep -n "DEVELOPMENT_TEAM" || true
git grep -n "PROVISIONING_PROFILE" || true

同时检查常见敏感文件：

find . -name "*.p12" -o -name "*.mobileprovision" -o -name "*.cer" -o -name "*.pem" -o -name "*.key"

要求：

1. 不得提交真实 AMAP Key
2. 不得提交个人证书
3. 不得提交 provisioning profile
4. 不得提交本地签名 Team ID，除非项目原来就是公开测试 Bundle ID 且无个人敏感信息
5. Config/LocalConfig.xcconfig 必须保持未跟踪或被忽略

如果发现敏感内容在 tracked 文件中，请先停止，输出风险报告，不要推送。

⸻

八、第六步：确认是否需要合并功能分支

当前可能存在多个功能分支：

haggi/step2-weather-provider
haggi/step2d-hourly-overview-behavior
haggi/step2e-dark-mode-readability

请执行：

git branch --all
git log --oneline --graph --decorate --all -30

目标是把当前最新稳定成果合并到主开发分支，建议使用：

main 或 master

请先确认远端默认分支名称：

git remote show origin

如果远端默认分支是 master，则使用 master。
如果远端默认分支是 main，则使用 main。

合并策略

假设远端默认分支是 master：

git checkout master
git pull origin master
git merge --no-ff haggi/step2e-dark-mode-readability -m "merge: Open-Meteo stable iOS build"

如果当前最新提交不在 haggi/step2e-dark-mode-readability，请改成实际最新分支。

如果有冲突：

1. 不要盲目覆盖
2. 优先保留最新功能分支代码
3. 但不要保留本地签名/个人设备配置
4. 解决后重新构建

⸻

九、第七步：构建验证

清理和合并完成后，必须验证构建。

执行：

xcodebuild -workspace GeometricWeather.xcworkspace -scheme GeometricWeather -configuration Debug -sdk iphonesimulator build

如果 workspace 或 scheme 名称不同，请自动识别。

再执行 Generic iPhoneOS build：

xcodebuild -workspace GeometricWeather.xcworkspace -scheme GeometricWeather -configuration Debug -destination 'generic/platform=iOS' build

如本机可用，也请执行 iPhone 17 Pro Max 真机构建，但不要把真机构建产生的本地文件提交。

⸻

十、第八步：最终 git 状态确认

推送前执行：

git status
git log --oneline --decorate -10
git diff --check

要求：

1. 工作区应干净，或只剩明确不提交的本地文件
2. git diff --check 必须通过
3. 最新 commit 应包含阶段 2A/2B/2D/2E 的所有代码
4. 不应包含 LocalConfig、密钥、证书、DerivedData、.DS_Store

⸻

十一、第九步：推送 GitHub

推送默认分支：

git push origin master

如果默认分支是 main，则：

git push origin main

推送 tag：

git push origin v0.3-openmeteo-stable

如果实际 tag 是 v0.3.1-openmeteo-stable，则推送实际 tag：

git push origin v0.3.1-openmeteo-stable

如需保留功能分支，也可以推送：

git push origin haggi/step2e-dark-mode-readability

但主目标是同步最新稳定代码到默认分支。

禁止使用：

git push --force

除非我明确要求。

⸻

十二、GitHub 推送后验证

推送完成后，请执行：

git ls-remote --heads origin
git ls-remote --tags origin

并输出：

1. 已推送分支
2. 已推送 tag
3. 远端最新 commit hash
4. 本地最新 commit hash
5. 是否一致

⸻

十三、完成后输出报告

请输出：

# 阶段 2F 仓库清理与 GitHub 同步报告
## 1. 当前分支与远端
- 本地当前分支
- origin 地址
- 默认分支
- 最新本地 commit
- 最新远端 commit
## 2. 清理内容
- 删除了哪些本地生成文件
- 更新了哪些 .gitignore 规则
- 哪些文件被保留
- 哪些文件被 restore
## 3. 敏感信息检查
- AMAP Key 检查结果
- LocalConfig 检查结果
- 证书 / profile 检查结果
- DEVELOPMENT_TEAM / signing 配置检查结果
## 4. 合并情况
- 从哪个功能分支合并到哪个默认分支
- 是否有冲突
- 如何解决
## 5. 构建验证
- Simulator build
- Generic iPhoneOS build
- 真机构建，如果执行
- git diff --check
## 6. 推送结果
- 推送分支
- 推送 tag
- 本地与远端 commit 是否一致
## 7. 当前仍未提交的本地文件
- 文件列表
- 为什么不提交
## 8. 后续建议
- 下一阶段建议

⸻

十四、立即开始

请现在开始阶段 2F：

1. 检查 git status / branch / remote
2. 创建稳定 tag
3. 清理 .DS_Store、DerivedData、本地 xcuserdata、Pods 本地 metadata
4. 判断 pbxproj 和 xcscheme 是否需要保留或 restore
5. 完善 .gitignore
6. 扫描敏感信息
7. 合并最新功能分支到 GitHub 默认分支
8. 构建验证
9. 推送默认分支和稳定 tag 到 GitHub
10. 输出完整报告

这里面最关键的是 project.pbxproj 和 .xcscheme：不要默认提交，也不要默认丢弃，必须先看 diff。
如果只是个人签名和本地设备配置，就 restore；如果包含新增源码文件加入 target 的必要配置，才提交。