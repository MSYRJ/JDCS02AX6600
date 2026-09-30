#!/bin/bash
# 组合配置并编译
set -e

WRT_DIR="${WRT_DIR:-$HOME/immortalwrt}"
cd "$WRT_DIR"

# 1. 组合 .config
echo "--- 组合配置文件 ---"
cat ax6600-Config/IPQ60XX-WIFI-YES.txt \
    ax6600-Config/GENERAL_AX6600.txt \
    ax6600-Config/GENERAL_AX6600_PLUS.txt > .config

# 追加 DAED 和 iStore
echo "CONFIG_PACKAGE_luci-app-daed=y" >> .config
echo "CONFIG_PACKAGE_luci-app-store=y" >> .config
echo "CONFIG_PACKAGE_luci-app-oaf=y" >> .config
echo "CONFIG_PACKAGE_kmod-oaf=y" >> .config
echo "CONFIG_PACKAGE_appfilter=y" >> .config

# 2. defconfig
echo "--- 运行 defconfig ---"
make defconfig

# 3. 检查关键项
echo "--- 检查关键配置 ---"
grep -E "CONFIG_PACKAGE_(luci-app-daed|luci-app-store|kmod-oaf|appfilter|luci-app-oaf)" .config

# 4. 下载依赖
echo "--- 下载依赖包 ---"
make download -j$(nproc) 2>&1 | tail -20

# 5. 编译
echo "--- 开始编译（建议在 screen 里跑）---"
make -j$(nproc) 2>&1 | tee build.log

echo ""
echo "=========================================="
echo "  编译完成！固件位于:"
echo "  $WRT_DIR/bin/targets/qualcommax/ipq60xx/"
echo "=========================================="
ls -lh "$WRT_DIR/bin/targets/qualcommax/ipq60xx/"*.bin 2>/dev/null || true
