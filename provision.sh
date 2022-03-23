#!/usr/bin/env bash

set -e

echo "[INFO ] Provision Progressing."


echo "[INFO ] DisableHistory Progressing."
unset HISTFILE
history -cw
echo "[INFO ] DisableHistory is Complete."


if [[ "$(id -u)" -ne 0 ]]
then
    echo >&2 "[ERROR] This script requires privileged access to system files and must be run as root."
    exit 99
fi


echo "[INFO ] SetEnvironmentVars Progressing."
export DEBIAN_FRONTEND="noninteractive"
export DEBCONF_NONINTERACTIVE_SEEN="true"
echo "[INFO ] SetEnvironmentVars is Complete."


echo "[INFO ] ConfigureApt Progressing."
cat <<'HEREDOC' >/etc/apt/apt.conf.d/90gzip-indexes
Acquire::GzipIndexes "true";
Acquire::CompressionTypes::Order:: "gz";
HEREDOC

cat <<'HEREDOC' >/etc/apt/apt.conf.d/90no-language
Acquire::Languages "none";
HEREDOC

cat <<'HEREDOC' >/etc/apt/apt.conf.d/90no-suggests-nor-recommends
APT::Install-Recommends "0";
APT::Install-Suggests "0" ;
HEREDOC

# open-vm-tools for arm64 can currently (2022-Mar-23rd) only be found in the bullseye-backports package repository
[ -f /etc/apt/sources.list.d/backports.list ] || cat <<'HEREDOC' >/etc/apt/sources.list.d/backports.list
deb http://deb.debian.org/debian bullseye-backports main contrib non-free
deb-src http://deb.debian.org/debian bullseye-backports main contrib non-free
HEREDOC
echo "[INFO ] ConfigureApt is Complete."


echo "[INFO ] InstallPackages Progressing."
apt-get -qq update
apt-get install -y -qq \
    ca-certificates           \
    fuse3                     \
    linux-headers-$(uname -r) \
    nfs-common                \
    open-vm-tools             \
    sudo                      \
    wget                      \
;
echo "[INFO ] InstallPackages is Complete."


echo "[INFO ] ConfigureSshD Progressing."

sed -i \
    -e '/UseDNS /s/.*\(UseDNS\) .*/\1 no/' \
    -e '/GSSAPIAuthentication /s/.*\(GSSAPIAuthentication\) .*/\1 no/' \
    /etc/ssh/sshd_config

# populate vagrant's default key (which is replaced upon :code:`$ vagrant up`)
wget -q https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub -O /tmp/authorized_keys
for usr in /home/*; do
    username="${usr##*/}"
    install --directory --owner=vagrant --group=vagrant --mode=0700 /home/vagrant/.ssh
    install --owner=vagrant --group=vagrant --mode=0600 --target-directory=/home/vagrant/.ssh /tmp/authorized_keys
done
rm -rf /tmp/authorized_keys
echo "[INFO ] ConfigureSshD is Complete."


echo "[INFO ] ConfigureModprobe Progressing."
# HACK: suppress flood of "Unknown ioctl 1976" on arm64 vms
#   https://github.com/vmware/photon/issues/1117#issuecomment-786656054
#
[ -f /etc/modprobe.d/blacklist-for-unknown-ioctl-1976-on-arm64.conf ] || cat <<HEREDOC >/etc/modprobe.d/blacklist-for-unknown-ioctl-1976-on-arm64.conf
blacklist vsock_loopback
blacklist vmw_vsock_virtio_transport_common
install vsock_loopback /usr/bin/true
install vmw_vsock_virtio_transport_common /usr/bin/true
HEREDOC
echo "[INFO ] ConfigureModprobe is Complete."


echo "[INFO ] ConfigureGrub Progressing."
# make bootup LOUD
sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=\).*/\1""/' /etc/default/grub
update-grub
echo "[INFO ] ConfigureGrub is Complete."


# System Cleanup removes caches and unneeded packages in order to produce the smallest box possible.
echo "[INFO ] SystemCleanup Progressing."

# remove old kernel versions and kernel header versions
apt-get -y -qq purge \
    $(dpkg -l | grep "linux-image-[0-9]" | grep "^ii" | tac | tail -n +2 | awk '{ print $2 }') \
    $(dpkg -l | grep "linux-headers-[0-9].*-arm64" | grep "^ii" | tac | tail -n +2 | awk '{ print $2 }') \
;
# including other no longer required packages
apt-get -y -qq autopurge
# and update grub incase there were entries for those kernels
update-grub

apt-get -y -qq purge \
    dictionaries* \
    emacs* \
    iamerican* \
    ibritish* \
    ienglish* \
    installation-report \
    ispell \
    libx11-6 \
    libx11-data \
    libxcb1 \
    libxext6 \
    libxmuu1 \
    nfacct \
    popularity-contest \
    tcpd \
    xauth \
    > /dev/null 2>&1
apt-get -y -qq --purge autoremove > /dev/null 2>&1
apt-get autoclean
apt-get clean

rm -rf /usr/share/info/*
rm -rf /usr/share/man/*
rm -rf /var/cache/apt/*
rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/dhcp/*
rm -rf /var/log/*
rm -rf /var/tmp/{..?*,.[!.]*,*}

# remove ipv6 only libraries
rm -rf /lib/xtables/libip6t_*.so

find /home /root -type f -not \( -name '.bashrc' -o -name '.bash_logout' -o -name '.profile' -o -name 'authorized_keys' \) -delete
find /usr/share/locale -mindepth 1 -maxdepth 1 -type d -not \( -name 'en' -o -name 'en_US' \) -exec rm -r {} ';'
find /usr/share/doc -mindepth 1 -not -type d -not -name 'copyright' -delete
find /usr/share/doc -mindepth 1 -type d -empty -delete
find /var/cache -type f -delete

sed -i -e '/cdrom/d' /etc/fstab

# empty the swap file
swap_part="$(swapon --show=NAME --noheadings --raw)"
swapoff "${swap_part}"
dd if=/dev/zero of="${swap_part}" > /dev/null 2>&1 || echo 'dd exit code suppressed'
mkswap -L SWAP "${swap_part}"
swapon "${swap_part}"

echo "COMPRESS=xz" > /etc/initramfs-tools/conf.d/compress
echo "RESUME=none" > /etc/initramfs-tools/conf.d/resume
update-initramfs -u # -u => Update an existing initramfs

dd if=/dev/zero of=/EMPTY bs=1M > /dev/null 2>&1 || echo 'dd exit code suppressed'
rm -f /EMPTY

sync
echo "[INFO ] SystemCleanup is Complete."


echo "[INFO ] SystemInfo:"
echo '--------------------------------------------------'
printf 'Debian: ..... ' ; cat /etc/debian_version
printf 'Filessytem: . ' ; du -sh / --exclude=/proc
printf 'OpenVmTools:  ' ; /usr/bin/vmware-toolbox-cmd -v
echo '--------------------------------------------------'


echo "[INFO ] Provision is Complete."
exit 0
