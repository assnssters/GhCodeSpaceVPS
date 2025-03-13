#!/bin/bash
# settings Func, Color Variable
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
blue='\033[1;34m'
light_cyan='\033[1;96m'
reset='\033[0m'
lines() {
echo
}
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
failu() {
echo -ne "$red $@"
exit 1
}

# Phân Vùng Mount (Copy @Ubuntu2310fake)
if mount | grep "on /mnt " > /dev/null; then
    echo "part is Mount /mnt. next!."
else
    echo "Find Part >500Gb.."
    partition=$(lsblk -b --output NAME,SIZE,MOUNTPOINT | awk '$2 > 500000000000 && $3 == "" {print $1}' | head -n 1)

    if [ -n "$partition" ]; then
        echo "part: /dev/$partition"
        sudo mount "/dev/${partition}1" /mnt
        if [ $? -ne 0 ]; then
            echo "Error Mount Part"
            exit 1
        fi
        echo -ne "$green /dev/$partition is mount to /mnt."
    else
        echo "$red error to Find part >500Gb"
        exit 1
    fi
fi

# Update Kho Lưu Trữ và Tải QEMU-KVM, Build SWTPM
echo -ne "$yellow Đang Cập nhật kho lưu trữ..."
lines
apt update -y > /dev/null 2>&1
spin $!
echo -ne "$yellow Ðang tải và cài đặt QEMU-KVM..."
lines
apt install p7zip-full qemu-kvm qemu-utils -y > /dev/null 2>&1
spin $!
echo -ne "$yellow BUILD SWTPM..(mất nhiều thời gian)$reset"
lines
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
while true; do
echo -ne """"$reset"hãy chọn Hệ Điều hành bạn muốn tải:
    1. Windows 11 x64 English Interational
    2. Windows Server 2025 x64 English
    3. Windows Server 2012 R2 x64 English
"""
read -p "chọn ( Số ): " stos
    case $stos in
        1) export ados="$(curl "https://raw.githubusercontent.com/assnssters/GhCodeSpaceVPS/refs/heads/main/11link.txt")";break;;
        2) export ados="https://go.microsoft.com/fwlink/?linkid=2293312&clcid=0x409&culture=en-us&country=us";break;;
        3) export ados="https://go.microsoft.com/fwlink/p/?LinkID=2195443&clcid=0x409&culture=en-us&country=US";break;;
        *) echo -ne "$red Unknown Hãy chạy lại.$reset";;
    esac
clear
done
wget $ados -O /mnt/os.iso && echo -ne "Tải thành công ISO!" || failu
cls
# Chọn Cấu hình
while true; do
echo -ne """Chọn cấu hình bạn muốn:
    1. Ram 4Gb, CPU 4 Cores(1)
    2. Ram 8Gb, CPU 4,4 Cores(1)
    3. Ram 4Gb, CPU 2 Cores(2)
    4. Ram 2Gb, CPU 2,2 Cores(2)
"""
read -p "chọn (số): " chos
case $chos in
    1) export ram=4G
       export cpu="cores=8"
       break
       ;;
    2) export ram=8G
       export cpu="4,cores=4"
       break
       ;;
    3) export ram=4G
       export cpu="cores=2"
       break
       ;;
    4) export ram=2G
       export cpu="2,cores=2"
       break
       ;;
    *) echo "chọn lại.";sleep 2;;
esac
cls
done
qemu-img create -f qcow2 /mnt/os.qcow2 401G
cls
echo "kết nối qua VNC ports(5900)"
sudo cpulimit -l 80 -- sudo kvm \
    -cpu host,+topoext,hv_relaxed,hv_spinlocks=0x1fff,hv-passthrough,+pae,+nx,kvm=on,+svm \
    -smp $cpu \
    -M q35,usb=on \
    -device usb-tablet \
    -m $ram \
    -device virtio-balloon-pci \
    -vga virtio \
    -net nic,netdev=n0,model=virtio-net-pci \
    -netdev user,id=n0,hostfwd=tcp::3389-:3389 \
    -boot d \
    -device virtio-serial-pci \
    -device virtio-rng-pci \
    -enable-kvm \
    -device nvme,serial=deadbeef,drive=nvm \
    -drive file=/mnt/os.qcow2,ìf=none,id=nvm \
    -drive file=/mnt/os.iso,media=cdrom \
    -drive if=pflash,format=raw,readonly=off,file=/usr/share/ovmf/OVMF.fd \
    -uuid e47ddb84-fb4d-46f9-b531-14bb15156336 \
    -vnc :0


    
