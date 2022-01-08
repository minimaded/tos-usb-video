#!/bin/bash

get_raspi2fb() {
    echo "Installing raspi2fb..."
    echo
    sudo mkdir -p /usr/lib/tos-usb-video || install_notdone
    sudo wget -O /usr/lib/tos-usb-video/raspi2fb https://github.com/minimaded/tos-usb-video/raw/main/raspi2fb || install_notdone
    sudo chmod +x /usr/lib/tos-usb-video/raspi2fb || install_notdone
}

install_script() {
    echo "Creating tos-usb-video.sh script..."
    echo
    cat << EOF | sudo tee "/usr/lib/tos-usb-video/tos-usb-video.sh" >/dev/null || update_notdone
#!/bin/bash

if [ -e /dev/tos-usb-video ] ; then {
    killall raspi2fb
    fbset -fb /dev/tos-usb-video -xres 1360
    raspi2fb --fps 60 --device /dev/tos-usb-video
}
fi
EOF

    sudo chmod +x /usr/lib/tos-usb-video/tos-usb-video.sh || install_notdone
}

udev_rules() {
    echo "Adding udev rules..."
    echo
    cat << EOF | sudo tee "/etc/udev/rules.d/99-tos-usb-video-add.rules" >/dev/null || update_notdone
ACTION=="add", SUBSYSTEM=="graphics", ATTRS{idVendor}=="17e9", ATTRS{idProduct}=="03a6", SYMLINK+="tos-usb-video", RUN{program}="/bin/systemctl start tos-usb-video.service"
EOF

    cat << EOF | sudo tee "sudo nano /etc/udev/rules.d/99-tos-usb-video-remove.rules" >/dev/null || update_notdone
ACTION=="add", SUBSYSTEM=="graphics", ATTRS{idVendor}=="17e9", ATTRS{idProduct}=="03a6", SYMLINK+="tos-usb-video", RUN{program}="/bin/systemctl start tos-usb-video.service"
EOF

    sudo udevadm control --reload-rules || install_notdone
}

systemd_service() {
    echo "Adding systemd service..."
    echo
    cat << EOF | sudo tee "/etc/systemd/system/tos-usb-video.service" >/dev/null || update_notdone
[Unit]
Description=HotSwap Toshiba DisplayLink Monitor

[Service]
ExecStart=/home/pi/tos-usb-video.sh
EOF

    sudo systemctl daemon-reload || install_notdone
}

install_done() {
    echo
    read -r -p "Install completed, press any key to exit... " -n1 -s
    exit 1  
}

install_notdone() {
    echo
    read -r -p "Install failed, press any key to exit... " -n1 -s
    exit 1  
}

get_raspi2fb
install_script
udev_rules
systemd_service
install_done
