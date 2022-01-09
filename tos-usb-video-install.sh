#!/bin/bash

set -eo pipefail

os_version() {
    osversion=$(cat /etc/os-release | grep VERSION_CODENAME | cut -f2 -d'=')
    case "$osversion" in
        buster | bullseye )
            echo "OS version is ${osversion}"
            echo
        ;;
        * )
            echo "OS version ${osversion} is not supported"
            echo
            install_notdone
        ;;
    esac
}

stop_clean() {
    if /bin/systemctl is-active -q tos-usb-video.service ; then
        echo "Stopping tos-usb-video.service"
        echo
        sudo /bin/systemctl stop tos-usb-video.service || install_notdone
    fi

    if /bin/pgrep -x "raspi2fb" 2>/dev/null ; then
        echo "Killing all raspi2fb processess"
        echo 
        sudo killall raspi2fb 2>/dev/null || install_notdone
    fi
}

get_raspi2fb() {
    
    for i in {1..60}; do
        if ping -c1 www.google.com &> /dev/null ; then
            break
        else
            echo "Waiting for an internet connection..."
            sleep 1
        fi
        if [ "${i}" -gt 59 ] ; then
            echo "Not connected to the internet..."
            echo
            install_notdone
        fi
    done

    echo "Installing raspi2fb..."
    echo
    sudo mkdir -p /usr/lib/tos-usb-video || install_notdone
    sudo wget -O "/usr/lib/tos-usb-video/raspi2fb-${osversion}" "https://github.com/minimaded/tos-usb-video/raw/main/raspi2fb-${osversion}" || install_notdone
    sudo chmod +x "/usr/lib/tos-usb-video/raspi2fb-${osversion}" || install_notdone
    sudo ln -f -s "/usr/lib/tos-usb-video/raspi2fb-${osversion}" /usr/bin/raspi2fb || install_notdone
}

install_script() {
    echo "Creating tos-usb-video.sh script..."
    echo
    cat << EOF | sudo tee "/usr/lib/tos-usb-video/tos-usb-video.sh" >/dev/null || install_notdone
#!/bin/bash

if [ -e /dev/tos-usb-video ] ; then
    killall raspi2fb
    fbset -fb /dev/tos-usb-video -xres 1360
    raspi2fb --fps 60 --device /dev/tos-usb-video
fi
EOF

    sudo chmod +x /usr/lib/tos-usb-video/tos-usb-video.sh || install_notdone
}

udev_rules() {
    echo "Adding udev rules..."
    echo
    cat << EOF | sudo tee "/etc/udev/rules.d/99-tos-usb-video-add.rules" >/dev/null || install_notdone
ACTION=="add", SUBSYSTEM=="graphics", ATTRS{idVendor}=="17e9", ATTRS{idProduct}=="03a6", SYMLINK+="tos-usb-video", RUN{program}="/bin/systemctl start tos-usb-video.service"
EOF

    cat << EOF | sudo tee "/etc/udev/rules.d/99-tos-usb-video-remove.rules" >/dev/null || install_notdone
ACTION=="remove", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{PRODUCT}=="17e9/3a6*", RUN{program}="/bin/systemctl stop tos-usb-video.service"
EOF

    sudo udevadm control --reload-rules || install_notdone
}

systemd_service() {
    echo "Adding systemd service..."
    echo
    cat << EOF | sudo tee "/etc/systemd/system/tos-usb-video.service" >/dev/null || install_notdone
[Unit]
Description=HotSwap Toshiba DisplayLink Monitor

[Service]
ExecStart=/usr/lib/tos-usb-video/tos-usb-video.sh
EOF

    sudo systemctl daemon-reload || install_notdone
}

display_settings() {
    echo "Setting display settings..."
    echo
    cat << EOF | sudo tee -a "/boot/config.txt" >/dev/null || install_notdone
gpu_mem_256=128
gpu_mem_512=256
gpu_mem_1024=256
hdmi_force_hotplug=1
hdmi_group=1
hdmi_mode=4
[EDID=*]
hdmi_group=0
[ALL]
EOF

    if [ $(egrep -c "^dtoverlay=vc4-kms-v3d" /boot/config.txt) -gt 0 ]
    then
        # comment out the parameter and reboot
        sudo sed -i -e "s/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/g" /boot/config.txt
    fi
}

install_done() {
    read -r -p < /dev/tty "Install completed, reboot? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            sudo reboot
    esac
    exit 0
}

install_notdone() {
    echo
    read -r -p < /dev/tty "Install failed, press any key to exit... " -n1 -s
    echo
    exit 1  
}

os_version
stop_clean
get_raspi2fb
install_script
udev_rules
systemd_service
display_settings
install_done
