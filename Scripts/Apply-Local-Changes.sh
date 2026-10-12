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
CONFIG_PACKAGE_msd_lite=y
CONFIG_PACKAGE_luci-app-msd_lite=y
EOF
    echo "中文/iStore/msd_lite 配置已追加"
fi

# =========================================================
# 10. wget-ssl（修复 apk update HTTPS 下载）
# =========================================================
if [ -f .config ]; then
    # 移除 wget-nossl，避免冲突
    sed -i '/^CONFIG_PACKAGE_wget-nossl=y$/d' .config
    # 启用 wget-ssl
    grep -q "CONFIG_PACKAGE_wget-ssl=y" .config || echo "CONFIG_PACKAGE_wget-ssl=y" >> .config
    echo "wget-ssl 配置已追加"
fi

# =========================================================
# 11. 温度显示（CPU / WiFi）
# =========================================================
if [ -f .config ]; then
    cat >> .config << 'EOF'
CONFIG_PACKAGE_luci-app-statistics=y
CONFIG_PACKAGE_collectd-mod-thermal=y
CONFIG_PACKAGE_collectd-mod-sensors=y
CONFIG_PACKAGE_lm-sensors=y
EOF
    echo "温度插件配置已追加"
fi

# =========================================================
# 12. PHY LED 触发支持（WAN 口千兆/百兆亮灯）
# =========================================================
if [ -f .config ]; then
    cat >> .config << 'EOF'
CONFIG_LED_TRIGGER_PHY=y
CONFIG_PACKAGE_kmod-ledtrig-netdev=y
EOF
    echo "PHY LED 触发配置已追加"
fi

# =========================================================
# 13. Python3 + requests（IPTV 脚本依赖）
# =========================================================
if [ -f .config ]; then
    cat >> .config << 'EOF'
CONFIG_PACKAGE_python3=y
CONFIG_PACKAGE_python3-pip=y
EOF
    echo "Python3 依赖已追加"
fi

# =========================================================
# 14. WAN 口 LED（2.5G PHY 千兆/百兆亮灯）
# =========================================================
DTS_FILE="target/linux/qualcommax/dts/ipq6010-re-cs-02.dts"
if [ -f "$DTS_FILE" ] && ! grep -q "phy0tpt" "$DTS_FILE"; then
    python3 << 'PYEOF'
dts = "target/linux/qualcommax/dts/ipq6010-re-cs-02.dts"
with open(dts) as f:
    c = f.read()
old = '''&mdio {
	qca8081: ethernet-phy@12 {
		compatible = "ethernet-phy-id004d.d101";
		reg = <12>;
		reset-deassert-us = <10000>;
		reset-gpios = <&tlmm 77 GPIO_ACTIVE_LOW>;
	};
};'''
new = '''&mdio {
	qca8081: ethernet-phy@12 {
		compatible = "ethernet-phy-id004d.d101";
		reg = <12>;
		reset-deassert-us = <10000>;
		reset-gpios = <&tlmm 77 GPIO_ACTIVE_LOW>;

		leds {
			#address-cells = <1>;
			#size-cells = <0>;

			led@0 {
				reg = <0>;
				color = <LED_COLOR_ID_GREEN>;
				function = LED_FUNCTION_LAN;
				function-enumerator = <1>;
				linux,default-trigger = "phy0tpt";
			};

			led@1 {
				reg = <1>;
				color = <LED_COLOR_ID_AMBER>;
				function = LED_FUNCTION_LAN;
				function-enumerator = <2>;
				linux,default-trigger = "phy0activity";
			};
		};
	};
};'''
if old in c:
    with open(dts, 'w') as f:
        f.write(c.replace(old, new))
    print("WAN LED 已添加")
else:
    print("WAN LED: 未找到匹配节点，跳过")
PYEOF
    echo "WAN LED 修改已应用"
fi

# =========================================================
# 15. IPTV 条件启动脚本（从大分区复制、pip 装 requests）
# =========================================================
mkdir -p package/base-files/files/etc/init.d
mkdir -p package/base-files/files/etc/uci-defaults
mkdir -p package/base-files/files/root

cat > package/base-files/files/etc/init.d/iptv-auto << 'IPTV_EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10

SRC_DIR="/mnt/mmcblk0p27/cmcc_iptv_auto_py"
DST_DIR="/root/cmcc_iptv_auto_py"
UPDATE_SCRIPT="/root/update_iptv.sh"

start() {
    i=0
    while [ ! -d "$SRC_DIR" ] && [ $i -lt 30 ]; do
        sleep 1
        i=$((i+1))
    done
    if [ ! -d "$SRC_DIR" ]; then
        echo "IPTV: 未找到 $SRC_DIR，跳过。"
        return 0
    fi
    rm -rf "$DST_DIR"
    cp -r "$SRC_DIR" "$DST_DIR"
    if [ ! -f "$DST_DIR/tv.py" ]; then
        return 0
    fi
    if ! python3 -c "import requests" 2>/dev/null; then
        j=0
        while ! ping -c1 -W2 223.5.5.5 >/dev/null 2>&1 && [ $j -lt 30 ]; do
            sleep 2
            j=$((j+1))
        done
        pip3 install requests -i https://pypi.tuna.tsinghua.edu.cn/simple \
            --break-system-packages >> /root/iptv_update.log 2>&1
    fi
    if ! crontab -l 2>/dev/null | grep -q "update_iptv.sh"; then
        (crontab -l 2>/dev/null; echo "0 3 * * * /root/update_iptv.sh >> /root/iptv_update.log 2>&1") | crontab -
    fi
    [ -f "$UPDATE_SCRIPT" ] && "$UPDATE_SCRIPT" &
}

stop() { :; }
IPTV_EOF

cat > package/base-files/files/etc/uci-defaults/99-enable-iptv-auto << 'IPTV_EOF'
#!/bin/sh
[ -f /etc/init.d/iptv-auto ] && /etc/init.d/iptv-auto enable
exit 0
IPTV_EOF

cat > package/base-files/files/root/update_iptv.sh << 'IPTV_EOF'
#!/bin/bash
if ! python3 -c "import requests" 2>/dev/null; then
    echo "$(date): requests 未安装，跳过更新"
    exit 1
fi
cd /root/cmcc_iptv_auto_py || exit 1
python3 tv.py
cp ku9.m3u tv2.m3u t.xml t.xml.gz /www/ 2>/dev/null
IPTV_EOF

chmod +x package/base-files/files/etc/init.d/iptv-auto
chmod +x package/base-files/files/etc/uci-defaults/99-enable-iptv-auto
chmod +x package/base-files/files/root/update_iptv.sh
echo "IPTV 脚本已创建"
