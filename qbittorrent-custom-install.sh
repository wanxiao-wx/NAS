#!/bin/bash

while getopts u:p:q:l:y flag
do
    case "${flag}" in
        u) WEB_USER=${OPTARG};;
        p) WEB_PASS=${OPTARG};;
        q) QBIT_VERSION=${OPTARG};;
        l) LIBTORRENT_VERSION=${OPTARG};;
        y) AUTO_YES=true;;
    esac
done

INSTALL_DIR="/usr/local/bin"
SERVICE_USER=$(whoami)
SERVICE_FILE="/etc/systemd/system/qbittorrent-nox@${SERVICE_USER}.service"
DOWNLOAD_URL="https://github.com/SAGIRIxr/Seedbox-Components/raw/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-${QBIT_VERSION}%20-%20libtorrent-${LIBTORRENT_VERSION}/qbittorrent-nox"

set -e

echo "==> 下载 qBittorrent ${QBIT_VERSION} + libtorrent ${LIBTORRENT_VERSION}..."
wget -q --show-progress "$DOWNLOAD_URL" -O qbittorrent-nox
chmod +x qbittorrent-nox
sudo mv qbittorrent-nox "$INSTALL_DIR/qbittorrent-nox"

echo "==> 创建 systemd 服务..."
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=qBittorrent-nox service for %i
After=network.target

[Service]
User=%i
ExecStart=$INSTALL_DIR/qbittorrent-nox
Restart=on-failure
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
EOF

echo "==> 启动服务..."
sudo systemctl daemon-reexec
sudo systemctl enable qbittorrent-nox@"$SERVICE_USER"
sudo systemctl start qbittorrent-nox@"$SERVICE_USER"

echo "==> 等待初始化配置文件..."
sleep 5

CONFIG_FILE="/home/${SERVICE_USER}/.config/qBittorrent/qBittorrent.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "==> 等待配置文件生成..."
    sleep 5
fi

echo "==> 修改默认 WebUI 用户名和密码..."
sed -i "s/^WebUI\\Username=.*/WebUI\\Username=${WEB_USER}/" "$CONFIG_FILE" || echo "WebUI\\Username=${WEB_USER}" >> "$CONFIG_FILE"
sed -i "s/^WebUI\\Password=.*/WebUI\\Password_PBKDF2=@ByteArray(${WEB_PASS})/" "$CONFIG_FILE" || echo "WebUI\\Password_PBKDF2=@ByteArray(${WEB_PASS})" >> "$CONFIG_FILE"
sed -i "s/^WebUI\\CSRFProtection=.*/WebUI\\CSRFProtection=false/" "$CONFIG_FILE" || echo "WebUI\\CSRFProtection=false" >> "$CONFIG_FILE"

echo "==> 重启服务应用配置..."
sudo systemctl restart qbittorrent-nox@"$SERVICE_USER"

echo "==> 安装完成！"
echo "访问地址：http://<你的服务器IP>:8080"
echo "用户名：${WEB_USER}"
echo "密码：${WEB_PASS}"
