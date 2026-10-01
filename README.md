# AX6600 本地编译指南

## 环境要求
- Ubuntu 22.04 / 24.04（64 位）
- 内存 ≥ 8GB（推荐 16GB+）
- 磁盘 ≥ 100GB 可用空间
- 能访问 GitHub（网络不稳定时需手动下载源码包）

## 目录结构
Openwrt-AX6600/

├── README.md

├── Config/ # 编译配置

│ ├── GENERAL_AX6600.txt # 通用配置（PURE/PLUS 共用）

│ ├── GENERAL_AX6600_PLUS.txt # PLUS 版增量配置

│ └── IPQ60XX-WIFI-YES.txt # 设备平台配置

├── Scripts/

│ ├── Dependencies.sh # ① 安装系统依赖

│ ├── Setup.sh # ② 克隆源码+应用定制

│ ├── Apply-Local-Changes.sh # ③ 本地修改（Setup 自动调用）

│ ├── Build.sh # ④ 编译固件

│ ├── Packages.sh # 插件克隆（Setup 自动调用）

│ └── Settings.sh # 原配置脚本

└── Docs/

└── 本地编译步骤.md



## 操作顺序（新电脑从零开始）

### 第一步：克隆本仓库
```bash
cd ~
git clone https://github.com/ones20250/Openwrt-AX6600.git ax6600-config
cd ax6600-config
```
第二步：安装系统依赖（只需一次）
```bash
bash Scripts/Dependencies.sh
```
第三步：搭建编译环境
bash
```bash
bash Scripts/Setup.sh
```
这个脚本会自动：

克隆 immortalwrt_ipq 源码到 ~/immortalwrt

更新 feeds

添加 iStore feed

克隆 PLUS 版插件（OpenClash/PassWall2 等）

克隆 DAED 和 OAF 源码

应用本地定制修改（内核分区 12M、WiFi 名 wlan、主机名 MSYRJ 等）

运行结束时会提示你手动下载 2 个文件（GitHub 直连不稳定）：

DAED 源码包 → 重命名为 daed-2026.08.26.tar.gz，放入 ~/immortalwrt/dl/

iStore 前端资源 → 重命名为 istore-ui-v0.2.0-2.tar.gz，放入 ~/immortalwrt/dl/

第四步：手动下载文件（关键）
在浏览器打开以下地址下载：

文件	下载地址	重命名为	放到
```bash
DAED 源码	https://github.com/daeuniverse/daed/archive/671e65d2fdcd62fe6a3ec18ecda209c5addea898.tar.gz	daed-2026.08.26.tar.gz	~/immortalwrt/dl/
iStore 前端	https://github.com/linkease/istore-ui/archive/refs/tags/v0.2.0-2.tar.gz	istore-ui-v0.2.0-2.tar.gz	~/immortalwrt/dl/
```
下载后执行，修正 DAED 哈希：

```bash
cd ~/immortalwrt
HASH=$(sha256sum dl/daed-2026.08.26.tar.gz | cut -d' ' -f1)
sed -i "s|^PKG_MIRROR_HASH:=.*|PKG_MIRROR_HASH:=$HASH|" package/luci-app-daed/daed/Makefile
echo "DAED 哈希已更新为: $HASH"
```
第五步：编译固件
```bash
bash Scripts/Build.sh
```
耗时约 1.5～3 小时（首次编译）。

第六步：找到固件
```bash
ls -lh ~/immortalwrt/bin/targets/qualcommax/ipq60xx/*.bin
```
刷机（路由器上执行）：

```bash
sysupgrade -n /tmp/xxx-sysupgrade.bin
```
后续更新
同步上游内核和插件更新

```bash
cd ~/immortalwrt
# 拉取上游核心源码更新
git remote add upstream https://github.com/ones20250/immortalwrt_ipq.git 2>/dev/null
git pull --rebase --autostash upstream main
```
# 更新 feeds
```bash
./scripts/feeds update -a
./scripts/feeds install -a
```
然后重新执行 
```bash
bash Scripts/Build.sh
```

只更新某个插件
```bash
cd ~/immortalwrt/package/插件目录
git pull
cd ~/immortalwrt
make package/插件名/compile V=s -j1
```


常见问题

Q: 编译报错 GnuTLS recv error / CONNECT tunnel failed

A: GitHub 访问不稳定。手动下载对应源码包放入 dl/，或稍后重试。




Q: kmod-oaf 编译报 del_timer_sync 未定义

A: 内核 6.18 已移除该函数。执行 bash Scripts/Apply-Local-Changes.sh 会自动修复。



Q: iStore 在界面看不到

A: 确认 .config 里有 CONFIG_PACKAGE_luci-app-store=y。没有则执行 make menuconfig，在 LuCI → 3. Applications 里勾选。



Q: 固件太大（180MB）

A: 固件包含 DAED/OpenClash/PassWall2/Docker/AdGuard Home 等重型插件。如需精简，用 ./scripts/size_compare.sh -p 分析并移除不需要的包。



