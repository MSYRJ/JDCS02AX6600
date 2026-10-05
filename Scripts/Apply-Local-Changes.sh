#!/bin/bash
# AX6600 本地定制修改，编译前应用
set -e

echo "=== 应用 AX6600 本地修改 ==="

# 1. 内核分区改为 12M
sed -i '/^define Device\/jdcloud_re-cs-02$/,/^endef$/ s/KERNEL_SIZE := 6144k/KERNEL_SIZE := 12288k/' \
    target/linux/qualcommax/image/ipq60xx.mk
sed -i '/^define Device\/jdcloud_re-cs-02$/,/^endef$/ s/DEVICE_VENDOR := JDCloud/DEVICE_VENDOR := MSYRJ/' \
    target/linux/qualcommax/image/ipq60xx.mk

# 2. WiFi 名称改为 wlan
sed -i "s/\.ssid='OWRT'/.ssid='wlan'/g; s/\.ssid='ImmortalWrt'/.ssid='wlan'/g; s/\.ssid='OpenWrt'/.ssid='wlan'/g" \
    package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

# 3. 主机名改为 MSYRJ
sed -i "s/hostname='OWRT'/hostname='MSYRJ'/g; s/hostname='ImmortalWrt'/hostname='MSYRJ'/g" \
    package/base-files/files/bin/config_generate

# 4. 注释 docker/dockerd 的 GitHub 校验
if [ -f feeds/packages/utils/docker/Makefile ]; then
    sed -i '53,58 s/^/# /' feeds/packages/utils/docker/Makefile
fi
if [ -f feeds/packages/utils/dockerd/Makefile ]; then
    sed -i '96,101 s/^/# /' feeds/packages/utils/dockerd/Makefile
fi

# 5. 修复 OAF 内核 API 适配
if [ -f package/OpenAppFilter/oaf/src/app_filter.c ]; then
    sed -i 's/del_timer_sync/timer_delete_sync/g' package/OpenAppFilter/oaf/src/app_filter.c
fi
if [ -f package/OpenAppFilter/oaf/src/af_client.c ]; then
    sed -i 's/del_timer_sync/timer_delete_sync/g' package/OpenAppFilter/oaf/src/af_client.c
    sed -i 's/from_timer(client, t, client_timer)/container_of(t, af_client_info_t, client_timer)/g' \
        package/OpenAppFilter/oaf/src/af_client.c
    grep -q "linux/timer.h" package/OpenAppFilter/oaf/src/af_client.c || \
        sed -i '1i #include <linux/timer.h>' package/OpenAppFilter/oaf/src/af_client.c
fi

echo "=== 本地修改应用完成 ==="

# =========================================================
# 6. eBPF / BTF 内核支持（DAED 必需）
# =========================================================
if [ -f .config ]; then
    cat >> .config << 'EOF'
CONFIG_DEVEL=y
CONFIG_BPF_TOOLCHAIN_HOST=y
# CONFIG_BPF_TOOLCHAIN_NONE is not set
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_BTF=y
# CONFIG_KERNEL_DEBUG_INFO_REDUCED is not set
CONFIG_KERNEL_XDP_SOCKETS=y
EOF
    echo "eBPF/BTF 配置已追加到 .config"
fi

# =========================================================
# 7. tc / iproute2 / kmod-sched（仅保留最小集）
# =========================================================
if [ -f .config ]; then
    # 先清除所有 kmod-sched 配置，避免重复
    sed -i '/^CONFIG_PACKAGE_kmod-sched/d' .config
    cat >> .config << 'EOF'
CONFIG_PACKAGE_tc-full=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_kmod-sched-core=y
CONFIG_PACKAGE_kmod-sched-bpf=y
EOF
    echo "tc/iproute2/kmod-sched 配置已追加到 .config"
fi

# =========================================================
# 9. 中文语言 + iStore + DAED geoip 依赖
# =========================================================
if [ -f .config ]; then
    cat >> .config << 'EOF'
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-app-store=y
CONFIG_PACKAGE_luci-lib-taskd=y
CONFIG_PACKAGE_luci-lib-xterm=y
CONFIG_PACKAGE_taskd=y
CONFIG_PACKAGE_xz-utils=y
CONFIG_PACKAGE_mount-utils=y
CONFIG_PACKAGE_tar=y
CONFIG_PACKAGE_daed-geoip=y
CONFIG_PACKAGE_daed-geosite=y
EOF
    echo "中文/iStore 配置已追加"
fi
