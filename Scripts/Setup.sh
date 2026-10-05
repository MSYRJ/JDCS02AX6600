#!/bin/bash
# 从零搭建编译环境：克隆源码、feeds、插件、应用定制
set -e

WORKSPACE="${WORKSPACE:-$HOME}"
WRT_DIR="$WORKSPACE/immortalwrt"
CFG_DIR="$WORKSPACE/ax6600-config"

# 如果脚本在仓库内运行，自动找到仓库目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/../Config" ]; then
    CFG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

echo "=== 工作目录: $WORKSPACE ==="
echo "=== 配置仓库: $CFG_DIR ==="

# 1. 克隆主源码
if [ ! -d "$WRT_DIR" ]; then
    echo "--- 克隆 immortalwrt_ipq 源码 ---"
    git clone --depth=1 --single-branch -b main \
        https://github.com/ones20250/immortalwrt_ipq.git "$WRT_DIR"
else
    echo "--- 源码目录已存在，跳过克隆 ---"
fi

# 2. 复制定制文件
echo "--- 复制定制配置和脚本 ---"
cp -r "$CFG_DIR/Scripts" "$WRT_DIR/"
cp -r "$CFG_DIR/Config" "$WRT_DIR/ax6600-Config"
chmod +x "$WRT_DIR/Scripts/"*.sh

# 3. 更新 feeds
echo "--- 更新 feeds ---"
cd "$WRT_DIR"
./scripts/feeds update -a
./scripts/feeds install -a

# 4. 添加 iStore feed
grep -q "istore" feeds.conf.default || \
    echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default
./scripts/feeds update istore
./scripts/feeds install -a -p istore
# 删除 feeds 里的旧版 OAF，避免覆盖 package/OpenAppFilter 官方源码
rm -rf feeds/packages/net/open-app-filter
# 添加 rtp2httpd feed
grep -q "rtp2httpd" feeds.conf.default || echo "src-git rtp2httpd https://github.com/stackia/rtp2httpd.git" >> feeds.conf.default
./scripts/feeds update rtp2httpd
./scripts/feeds install rtp2httpd

# 5. 克隆 PLUS 插件
echo "--- 克隆 PLUS 版插件 ---"
cd "$WRT_DIR/package"
WRT_PROFILE=PLUS "$WRT_DIR/Scripts/Packages.sh"

# 6. 克隆 DAED 和 OAF
echo "--- 克隆 DAED 和 OAF ---"
[ -d luci-app-daed ] || git clone --depth=1 https://github.com/QiuSimons/luci-app-daed.git
[ -d OpenAppFilter ] || git clone --depth=1 https://github.com/destan19/OpenAppFilter.git

# 7. 应用本地修改
echo "--- 应用本地修改 ---"
cd "$WRT_DIR"
bash Scripts/Apply-Local-Changes.sh

# 8. 手动下载提示
echo ""
echo "=========================================="
echo "  下一步：手动下载以下文件到 $WRT_DIR/dl/"
echo "=========================================="
echo "1. DAED 源码包："
echo "   https://github.com/daeuniverse/daed/archive/671e65d2fdcd62fe6a3ec18ecda209c5addea898.tar.gz"
echo "   下载后重命名为: daed-2026.08.26.tar.gz"
echo ""
echo "2. iStore 前端资源："
echo "   https://github.com/linkease/istore-ui/archive/refs/tags/v0.2.0-2.tar.gz"
echo "   下载后重命名为: istore-ui-v0.2.0-2.tar.gz"
echo ""
echo "3. DAED 源码包哈希修正："
echo "   sha256sum \$WRT_DIR/dl/daed-2026.08.26.tar.gz"
echo "   把结果写入 package/luci-app-daed/daed/Makefile 的 PKG_MIRROR_HASH"
echo ""
echo "完成后执行: bash Scripts/Build.sh"
