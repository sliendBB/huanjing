#!/bin/bash
# 文件名：manage_env.sh
# 用途：安装 / 卸载 环境，通过下载并执行指定脚本

# 下载函数，$1 传入 mysql / ydinstall / ydindd
download() {
  local name=$1
  local url_base="http://124.70.188.27:6688"
  case "$name" in
    mysql)
      echo "下载 mysql-packages.tar.gz..."
      curl -sSL -o /root/mysql-packages.tar.gz "${url_base}/mysql-packages.tar.gz"
      ;;
    ydinstall)
      echo "下载 ydinstall.sh..."
      curl -sSL -o /root/ydinstall.sh "${url_base}/ydinstall.sh"
      chmod +x /root/ydinstall.sh
      ;;
    ydindd)
      echo "下载 ydindd.sh..."
      curl -sSL -o /root/ydindd.sh "${url_base}/ydindd.sh"
      chmod +x /root/ydindd.sh
      ;;
    *)
      echo "未知文件：$name"
      exit 1
      ;;
  esac
}

# 安装流程
install_env() {
  download mysql
  download ydinstall

  echo "解压安装包..."
  tar -zxvf /root/mysql-packages.tar.gz -C /root

  echo "执行安装脚本..."
  /bin/bash /root/ydinstall.sh

}

# 卸载流程
uninstall_env() {
  download ydindd

  echo "执行卸载脚本..."
  /bin/bash /root/ydindd.sh
  echo "卸载完成"
}

# 清屏
clear

# 菜单
while true; do
  cat <<EOF

===========================================
|                                         |
|           系统环境管理工具              |
|                                         |
===========================================

   >> [1] centos 9环境安装

   >> [2] 环境卸载

   >> [3] 退出

-------------------------------------------
!!! 温馨提示：如需重装环境，请先卸载再安装 !!!
-------------------------------------------

EOF
  read -p "请选择操作 [1-3]: " choice
  case "$choice" in
    1) install_env; break ;;
    2) uninstall_env; break ;;
    3) echo "退出脚本。"; exit 0 ;;
    *) echo "无效选项，请重新输入。" ;;
  esac
done
