#!/bin/bash
set -e

# 停止服务
echo "停止服务..."
systemctl stop mysqld 2>/dev/null || true
systemctl disable mysqld 2>/dev/null || true

# 卸载包
echo "卸载组件..."
dnf remove -y \
  mysql-community-server \
  mysql-community-client \
  mysql-community-client-plugins \
  mysql-community-common \
  mysql-community-icu-data-files \
  mysql-community-libs \
  mysql-connector-odbc

# 清理文件
echo "清理文件..."
rm -rf \
  /var/lib/mysql \
  /var/log/mysqld.log \
  /root/mysql8 \
  /etc/my.cnf.rpmsave \
  /etc/odbc.ini

# 清理证书
echo "清理证书..."
rm -rf /etc/mysql/ssl

# 恢复配置
echo "恢复配置..."
sed -i '/ssl-ca/d;/ssl-cert/d;/ssl-key/d' /etc/my.cnf 2>/dev/null || true


# 清理依赖
echo "清理依赖..."
dnf autoremove -y

# 重置ODBC
echo "重置ODBC..."
mv /etc/odbc.ini /etc/odbc.ini.bak 2>/dev/null || true

echo "
=========================================================
||                                                     ||
||                  卸载完成！                         ||
||                                                     ||
=========================================================
"