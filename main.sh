#!/bin/bash
# settings Func, Color Variable
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
light_cyan='\033[1;96m'
reset='\033[0m'
cls() {
    clear
}
spin() {
    local pid=$1  # PID
    local chars="/-\|"
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#chars}; i++ )); do
            echo -ne "${chars:$i:1} \r"
            sleep 0.1
        done
    done
}
# Update Kho Lưu Trữ và Tải QEMU-KVM, Build SWTPM
echo -ne "$yellow Đang Cập nhật kho lưu trữ..."
apt update -y > /dev/null 2>&1
spin $!
echo -ne "$yellow Ðang tải và cài đặt QEMU-KVM..."
apt install p7zip-full qemu-kvm -y > /dev/null 2>&1
spin $!
echo -ne "$yellow BUILD SWTPM..(mất nhiều thời gian)$reset"
echo Đang tải...
sleep 3
apt install git g++ gcc automake autoconf libtool make gcc libc-dev libssl-dev pkg-config libtasn1-6-dev libjson-glib-dev expect gawk socat libseccomp-dev -y > /dev/null 2>&1
cd ~
git clone https://github.com/stefanberger/swtpm.git
git clone https://github.com/stefanberger/libtpms.git
cd libtpms
./autogen.sh --prefix=/usr --with-tpm2 --with-openssl
make
sudo make install
cd ../swtpm
./autogen.sh --prefix=/usr
make
sudo make install
cd ..
rm -rf swtpm/ libtpms/
echo -ne "$reset"
cls
# Chọn ISO OS
echo -ne """"$reset"hãy chọn Hệ Điều hành bạn muốn tải:
    1. Windows 11 x64 English Interational
    2. Windows Server 2025 x64 English
    3. Windows Server 2012 R2 x64 English
    4. Custom ISO ( LINK )
"""
read -p "chọn ( Số ): " stos
case $stos in
    1) export ados="$(curl "https://raw.githubusercontent.com/assnssters/GhCodeSpaceVPS/refs/heads/main/11link.txt")";;
    2) export ados="https://go.microsoft.com/fwlink/?linkid=2293312&clcid=0x409&culture=en-us&country=us";;
    3) export ados="https://go.microsoft.com/fwlink/p/?LinkID=2195443&clcid=0x409&culture=en-us&country=US";;
    4) export ados=$(read -p "link: " ah && echo $ah );;
    *) echo -ne "$red Unknown Hãy chạy lại.$reset";;
esac
wget $ados -O /mnt/os.iso







    
