#!/bin/bash
set -e  # 脚本执行出错时自动退出

# 步骤1：用户输入 MySQL root 密码
read -p "请输入MySQL root密码(): " MYSQL_ROOT_PASSWORD
echo

# 安装依赖
yum install perl net-tools libaio zip -y
yum -y remove mysql-libs
yum install perl libnuma* -y

# 设置MySQL仓库
sudo tee /etc/yum.repos.d/mysql-community.repo <<-'EOF'
[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=https://repo.mysql.com/yum/mysql-8.0-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql

[mysql-connectors-community]
name=MySQL Connectors Community
baseurl=https://repo.mysql.com/yum/mysql-connectors-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql

[mysql-tools-community]
name=MySQL Tools Community
baseurl=https://repo.mysql.com/yum/mysql-tools-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=https://repo.mysql.com/RPM-GPG-KEY-mysql
EOF

# 更新缓存
sudo dnf clean all
sudo dnf makecache

# 创建工作目录
TARGET_DIR="/root/mysql8"
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 下载MySQL包
echo "下载MySQL组件..."
dnf download \
  mysql-community-client \
  mysql-community-client-plugins \
  mysql-community-common \
  mysql-community-icu-data-files \
  mysql-community-libs \
  mysql-community-server \
  mysql-connector-odbc

# 提取SQL文件
TAR_FILE="/root/mysql-packages.tar.gz"
echo "提取SQL文件..."
tar -xzf "$TAR_FILE" --wildcards "*.sql" -C "$TARGET_DIR"

# 安装RPM包
echo "安装MySQL..."
dnf install -y \
  mysql-community-common-*.rpm \
  mysql-community-libs-*.rpm \
  mysql-community-client-plugins-*.rpm \
  mysql-community-icu-data-files-*.rpm \
  mysql-community-client-*.rpm \
  mysql-community-server-*.rpm \
  mysql-connector-odbc-*.rpm

# 启动服务
systemctl enable mysqld
systemctl start mysqld

# 获取临时密码
TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
echo "初始密码: $TEMP_PASSWORD"

# 修改密码和权限
echo "修改密码和权限..."
mysql --connect-expired-password -uroot -p"$TEMP_PASSWORD" <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$TEMP_PASSWORD';
FLUSH PRIVILEGES;
SET GLOBAL validate_password.policy = 0;         
SET GLOBAL validate_password.length = 4;        
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
CREATE USER 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# 创建配置文件
echo "创建配置文件..."
cat <<EOF > /root/.my.cnf
[client]
user = root
password = $MYSQL_ROOT_PASSWORD
host = localhost
EOF
chmod 600 /root/.my.cnf

# 修改认证插件
echo "修改认证插件..."
mysql --defaults-file=/root/.my.cnf <<EOF
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF

# 生成SSL证书
echo "生成SSL证书..."
OPENSSL_DIR="/etc/mysql/ssl"
mkdir -p "$OPENSSL_DIR"
yum install -y openssl

openssl genpkey -algorithm RSA -out "$OPENSSL_DIR/server-key.pem"
openssl req -new -key "$OPENSSL_DIR/server-key.pem" -out "$OPENSSL_DIR/certificate_request.csr" -subj "/CN=mysql-server"
openssl x509 -req -days 365 -in "$OPENSSL_DIR/certificate_request.csr" -signkey "$OPENSSL_DIR/server-key.pem" -out "$OPENSSL_DIR/server-cert.pem"
cp "$OPENSSL_DIR/server-cert.pem" "$OPENSSL_DIR/ca.pem"

# 配置SSL
echo "配置SSL..."
cat <<EOF >> /etc/my.cnf
[mysqld]
ssl-ca = $OPENSSL_DIR/ca.pem
ssl-cert = $OPENSSL_DIR/server-cert.pem
ssl-key = $OPENSSL_DIR/server-key.pem
EOF

# 配置ODBC
echo "配置ODBC..."
cat <<EOF > /etc/odbc.ini
[tlbbdb]
Driver          = /usr/lib64/libmyodbc8a.so
SERVER          = 127.0.0.1
PORT            = 3306
USER            = root
Password        = $MYSQL_ROOT_PASSWORD
Database        = tlbbdb
OPTION          = 3
SOCKET          =
EOF

# 导入SQL文件
echo "导入数据库..."
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS tlbbdb"
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" tlbbdb < "$TARGET_DIR/tlbbdb.sql"

mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS web"
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" web < "$TARGET_DIR/web.sql"

# 重启服务
echo "重启MySQL..."
systemctl restart mysqld

# 清理文件
echo "清理文件..."
rm -f \
  /root/ydinstall.sh \
  /root/ydindd.sh \
  /root/mysql-packages.tar.gz
  
echo "
=========================================================
||                                                     ||
||                  安装完成！                         ||
||                                                     ||
=========================================================
联系方式: 小新QQ 2319342688 | QQ交流群 1012771797
"
