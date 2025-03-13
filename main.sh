#!/bin/bash

# Variable Màu
red='\033[1;31m'
green='\033[1;32m'
yellow='\033[1;33m'
reset='\033[0m'

# Tìm ổ đĩa trên 500Gb
if mount | grep -q "on /mnt "; then
    echo -e "$green Ổ đã được mount vào /mnt. Tiếp tục...$reset"
else
    echo -e "$yellow Tìm ổ cứng >500GB...$reset"
    
    partition=$(lsblk -b --output NAME,SIZE,MOUNTPOINT | awk '$2 > 500000000000 && $3 == "" {print $1}' | head -n 1)

    if [[ -n "$partition" ]]; then
        echo -e "$green Tìm thấy ổ: /dev/$partition$reset"

        if ! sudo blkid "/dev/${partition}1" &>/dev/null; then
            echo -e "$yellow Phân vùng chưa được định dạng, tiến hành format...$reset"
            sudo mkfs.ext4 "/dev/${partition}1"
        fi

        sudo mkdir -p /mnt
        sudo mount "/dev/${partition}1" /mnt

        if [[ $? -eq 0 ]]; then
            echo -e "$green /dev/${partition}1 đã được mount vào /mnt.$reset"
        else
            echo -e "$red Lỗi khi mount ổ đĩa!$reset"
            exit 1
        fi
    else
        echo -e "$red Không tìm thấy ổ nào trên 500GB!$reset"
        exit 1
    fi
fi

# Cập nhật Và Tải Các gói
echo -e "$yellow Cập nhật kho lưu trữ...$reset"
sudo apt update -y > /dev/null 2>&1
sudo apt install p7zip-full > /dev/null 2>&1
echo -e "$yellow Cài đặt QEMU-KVM...$reset"
if ! command -v kvm &>/dev/null; then
    echo "Lệnh 'kvm' không tồn tại, đang cài đặt QEMU-KVM..."
    sudo apt install -y qemu-kvm > /dev/null 2>&1
fi

if ! command -v qemu-img &>/dev/null; then
    echo "Lệnh 'qemu-img' không tồn tại, đang cài đặt QEMU-KVM..."
    sudo apt install -y qemu-utils > /dev/null 2>&1
fi

# Check lệnh SWTPM và build SWTPM
if ! command -v swtpm &>/dev/null; then
    echo -e "$yellow SWTPM không có trên hệ thống, tiến hành cài đặt...$reset"
    sleep 2

    sudo apt install -y git g++ gcc automake autoconf libtool make gcc libc-dev \
        libssl-dev pkg-config libtasn1-6-dev libjson-glib-dev expect \
        gawk socat libseccomp-dev > /dev/null 2>&1

    cd ~ || exit

    git clone https://github.com/stefanberger/libtpms.git && \
    cd libtpms && ./autogen.sh --prefix=/usr --with-tpm2 --with-openssl && make -j$(nproc) && sudo make install
    cd ..

    git clone https://github.com/stefanberger/swtpm.git && \
    cd swtpm && ./autogen.sh --prefix=/usr && make -j$(nproc) && sudo make install
    cd ..

    rm -rf swtpm/ libtpms/
fi

clear

# Chọn bệ điều hành muốn cài.
while true; do
    echo -e "$reset Hãy chọn Hệ Điều hành bạn muốn tải:\n
    1. Windows 11 x64 English International\n
    2. Windows Server 2025 x64 English\n
    3. Windows Server 2012 R2 x64 English\n"

    read -p "Chọn (Số): " stos

    case $stos in
        1) ados=$(curl -fsSL "https://raw.githubusercontent.com/assnssters/GhCodeSpaceVPS/refs/heads/main/11link.txt");;
        2) ados="https://go.microsoft.com/fwlink/?linkid=2293312&clcid=0x409&culture=en-us&country=us";;
        3) ados="https://go.microsoft.com/fwlink/p/?LinkID=2195443&clcid=0x409&culture=en-us&country=US";;
        *) echo -e "$red Lựa chọn không hợp lệ! Hãy thử lại.$reset"; continue;;
    esac

    if [[ -z "$ados" ]]; then
        echo -e "$red Lỗi khi tải đường dẫn. Hãy thử lại!$reset"
        continue
    fi

    break
done

clear
echo "Đang tải file ISO..."
wget "$ados" -O /mnt/os.iso && echo -e "$green Tải thành công ISO!$reset" || { echo -e "$red Tải Không thành công ISO, Vui lòng chạy lại script.$reset"; exit 1; }

clear

# Lựa chọn cấu hình
while true; do
    echo -e "Chọn cấu hình bạn muốn:\n
    1. Ram 4GB, CPU 4 Cores\n
    2. Ram 8GB, CPU 4 Cores\n
    3. Ram 4GB, CPU 2 Cores\n
    4. Ram 2GB, CPU 2 Cores\n"

    read -p "Chọn (số): " chos

    case $chos in
        1) export ram="4G"; export cpu="cores=4"; break;;
        2) export ram="8G"; export cpu="cores=4"; break;;
        3) export ram="4G"; export cpu="cores=2"; break;;
        4) export ram="2G"; export cpu="cores=2"; break;;
        *) echo "Lựa chọn không hợp lệ. Vui lòng thử lại!"; sleep 2;;
    esac
done

clear
echo "Cấu hình đã chọn: RAM=$ram, CPU=$cpu"
echo "Kết nối qua VNC ports (5900)"

sudo swtpm socket --tpmstate dir=/tmp/mytpm1 --ctrl type=unixio,path=/tmp/mytpm1/swtpm-sock --tpm2 &

sudo cpulimit -l 80 -- sudo kvm \
    -cpu host,+topoext,hv_relaxed,hv_spinlocks=0x1fff,hv-passthrough,+pae,+nx,kvm=on,+svm \
    -smp "$cpu" \
    -M q35,usb=on \
    -device usb-tablet \
    -m "$ram" \
    -device virtio-balloon-pci \
    -vga virtio \
    -net nic,netdev=n0,model=virtio-net-pci \
    -netdev user,id=n0,hostfwd=tcp::3389-:3389 \
    -boot d \
    -device virtio-serial-pci \
    -device virtio-rng-pci \
    -chardev socket,id=chrtpm,path=/tmp/mytpm1/swtpm-sock \
    -tpmdev emulator,id=tpm0,chardev=chrtpm \
    -device tpm-tis,tpmdev=tpm0 \
    -enable-kvm \
    -device nvme,serial=deadbeef,drive=nvm \
    -drive file=/mnt/os.qcow2,if=none,id=nvm \
    -drive file=/mnt/os.iso,media=cdrom \
    -drive if=pflash,format=raw,readonly=off,file=/usr/share/ovmf/OVMF.fd \
    -uuid e47ddb84-fb4d-46f9-b531-14bb15156336 \
    -vnc :0
