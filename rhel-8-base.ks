# RHEL 8 base / OpenStack / cloud example kickstart file
#
# Install:
# virt-install \
#   --connect qemu:///system --name test --virt-type kvm --arch x86_64 \
#   --vcpus 2 --cpu host --ram 2048 --os-type linux --os-variant rhel7.6 \
#   --disk pool=default,format=qcow2,cache=none,io=native,size=8 \
#   --network network=default --graphics vnc --sound none --noreboot \
#   --location /VirtualMachines/boot/rhel-server-8.0-x86_64-dvd.iso \
#   --initrd-inject /VirtualMachines/boot/ks/rhel-8-base.ks \
#   --extra-args "ip=dhcp inst.noblscfg inst.ks=file:/rhel-8-base.ks console=tty0 console=ttyS0,115200 net.ifnames.prefix=net quiet systemd.show_status=yes" \
#   --noautoconsole
#
# Post-process:
# 1) virt-sysprep --root-password password:foobar -a ./rhel.qcow2
# 2) virt-sparsify --compress|--in-place ./rhel.qcow2

cmdline
zerombr
clearpart --all
bootloader --timeout=1 --append="console=tty0 console=ttyS0,115200 net.ifnames.prefix=net ipv6.disable=1 quiet systemd.show_status=yes"
reqpart
#part /boot/efi --fstype=efi --ondisk=vda --size=200 --fsoptions="umask=0077,shortname=winnt"
#part /boot --fstype xfs --asprimary --size 1024
#part swap --fstype swap --asprimary --size 1024
part / --fstype xfs --asprimary --size 1024 --grow
selinux --enforcing
auth --useshadow --passalgo=sha512
rootpw --plaintext foobar
#network --device net0 --bootproto dhcp --onboot yes --hostname localhost
#--noipv6
firewall --enabled --service=ssh
firstboot --disabled
lang en_US.UTF-8
timezone --ntpservers=0.rhel.pool.ntp.org --utc Europe/Helsinki
keyboard fi
services --enabled tuned
poweroff

%addon com_redhat_kdump --enable --reserve-mb=auto
%end

%packages --instLangs=en_US
# --excludedocs
# --excludeWeakdeps
# --ignoremissing
@Core
bash-completion
#bind-utils
#boom-boot*
bzip2
#cloud-init
#cloud-utils-growpart
chrony
dnf-utils
#drpm
#iotop
man-pages
mlocate
nano
#net-tools
openssh-clients
prefixdevname
psmisc
python3
python3-libselinux
python3-policycoreutils
strace
#tcpdump
#telnet
#tmux
tuned
#unzip
util-linux-user
#watchdog
wget
zsh

-a*firmware*
-biosdevname
-dracut-config-rescue
-geolite2-*
-i*firmware*
-initscripts
-iprutils
-kernel-tools
-lib*firmware*
-libxkbcommon
-network-scripts
#-NetworkManager*
-NetworkManager-team
-NetworkManager-tui
-parted
-plymouth
-rdma*
-*rhn*
-sqlite
-sssd*
-subs*

# BIOS/UEFI cross-compatibility packages
#efibootmgr
#grub2-tools*
#grub2-pc
#grub2-pc-modules
#grub2-efi-x64
#grub2-efi-x64-modules
#shim-x64

# Guest utilities, always include either one
qemu-guest-agent
#open-vm-tools

# For (virtual) HW inspection
#dmidecode
#pciutils
#virt-what

# Ultra lean
#-audit
#-authselect*
#-cracklib-dicts
#-e2fsprogs
#-firewalld
#-lshw
#-kbd
#-kexec-tools
#-polkit
#-postfix
#-rootfiles
#-sg3_utils*
#-trousers
#-tuned
#-yum
%end

%post --erroronfail
# GRUB / console
#sed -i -e 's,GRUB_TERMINAL.*,GRUB_TERMINAL="serial console",' /etc/default/grub
#sed -i -e '/GRUB_SERIAL_COMMAND/d' -e '$ i GRUB_SERIAL_COMMAND="serial --speed=115200"' /etc/default/grub
#sed -i -e 's/console=tty0 //' -e 's/ console=ttyS0,115200//' /etc/default/grub
sed -i -e 's,rhgb ,,g' /etc/default/grub
test -f /boot/grub2/grub.cfg && grubcfg=/boot/grub2/grub.cfg || grubcfg=/boot/efi/EFI/redhat/grub.cfg
grub2-mkconfig -o $grubcfg
systemctl enable serial-getty@ttyS0.service
#systemctl enable serial-getty@ttyS1.service
#echo ttyS1 >> /etc/securetty

# GRUB BIOS/UEFI cross-compatibility (needs UEFI)
#for grubcfg in /boot/grub2/grub.cfg /boot/efi/EFI/redhat/grub.cfg; do
#  grub2-mkconfig -o $grubcfg
#  sed -i -n '1,/BEGIN.*uefi.*/p;/END.*uefi.*/,$p' $grubcfg
#done
#grub2-install --force --target=i386-pc /dev/vda > /dev/null 2>&1 || :

# Modules
echo blacklist intel_rapl >> /etc/modprobe.d/blacklist.conf
echo blacklist snd_pcsp >> /etc/modprobe.d/blacklist.conf
echo blacklist pcspkr >> /etc/modprobe.d/blacklist.conf

# Guest Agent / Performance
mkdir -p /etc/qemu-ga /etc/tuned
echo '[general]' > /etc/qemu-ga/qemu-ga.conf
echo 'verbose=1' >> /etc/qemu-ga/qemu-ga.conf
echo virtual-guest > /etc/tuned/active_profile

# Networking
netdevprefix=net
rpm -q NetworkManager > /dev/null 2>&1 && nm=yes || nm=no
grep -q ipv6.disable=1 /etc/default/grub && ipv6=no || ipv6=yes
for i in 0; do
  cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-$netdevprefix$i
DEVICE=$netdevprefix$i
TYPE=Ethernet
#HWADDR=
#UUID=
ONBOOT=yes
BOOTPROTO=dhcp
NM_CONTROLLED=$nm
NOZEROCONF=yes
DEFROUTE=no
IPV6_DEFROUTE=no
PERSISTENT_DHCLIENT=yes
IPV6INIT=$ipv6
DHCPV6C=$ipv6
IPV4_FAILURE_FATAL=yes
IPV6_FAILURE_FATAL=$ipv6
EOF
done
sed -i -e 's,DEFROUTE=no,DEFROUTE=yes,' /etc/sysconfig/network-scripts/ifcfg-${netdevprefix}0

# ssh/d
sed -i -e 's,^#UseDNS.*,UseDNS no,' /etc/ssh/sshd_config
# https://lists.centos.org/pipermail/centos-devel/2016-July/014981.html
echo "OPTIONS=-u0" >> /etc/sysconfig/sshd
mkdir -m 0700 -p /root/.ssh
#echo "ssh-rsa ..." > /root/.ssh/authorized_keys
restorecon -R /root/.ssh > /dev/null 2>&1

# Repositories
if [ ! -f /etc/centos-release ]; then
  repofile=intra.repo
  repohost=192.168.122.1
  /bin/rm -f /etc/yum.repos.d/* > /dev/null 2>&1
  ping -c1 -q $repohost > /dev/null 2>&1 && \
    curl http://$repohost/ks/$repofile -o /etc/yum.repos.d/$repofile
  grep -q name= /etc/yum.repos.d/$repofile > /dev/null 2>&1 || \
    rm -f /etc/yum.repos.d/$repofile
fi

# Packages - keys
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release > /dev/null 2>&1 || :
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-8 > /dev/null 2>&1 || :

# Packages - trimming
echo "%_install_langs en_US" > /etc/rpm/macros.install-langs-conf
#echo "%_excludedocs 1" > /etc/rpm/macros.excludedocs-conf
#echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
dnf -C -y remove linux-firmware > /dev/null 2>&1 || :

# Packages - EPEL
#dnf -y install epel-release

# Packages - update
#dnf -y update
if [ $(rpm -q kernel | wc -l) -gt 1 ]; then
  dnf -C -y remove $(rpm -q --last kernel | awk 'FNR>1{print $1}')
fi

# Services
systemctl disable dnf-makecache.timer nis-domainname.service remote-fs.target
rpm -q NetworkManager > /dev/null 2>&1 || systemctl enable network.service

# Watchdog
if [ -f /etc/watchdog.conf ]; then
  sed -i -e 's,^#watchdog-device,watchdog-device,' /etc/watchdog.conf
  systemctl enable watchdog.service
fi

# cloud-init
#dnf -y install cloud-init cloud-utils-growpart
if [ -f /etc/cloud/cloud.cfg ]; then
  sed -i -e 's/DEBUG/WARNING/g' /etc/cloud/cloud.cfg.d/05_logging.cfg
  sed -i -e '1i \\' /etc/cloud/cloud.cfg
  sed -i -e '1i datasource_list: [ OpenStack, None ]\' /etc/cloud/cloud.cfg
  sed -i -e '/disable_root/s/1/0/' /etc/cloud/cloud.cfg
  sed -i -e '/ssh_pwauth/s/0/1/' /etc/cloud/cloud.cfg
  sed -i -e '/locale_configfile/d' /etc/cloud/cloud.cfg
  if [ ! -f /etc/centos-release ]; then
    sed -i -e '/ - default/a \ - name: cloud-user' /etc/cloud/cloud.cfg
    sed -i -e '/ - name: cloud-user/a \ \ \ ssh-authorized-keys:' /etc/cloud/cloud.cfg
  else
    sed -i -e '/ - default/a \ - name: centos' /etc/cloud/cloud.cfg
    sed -i -e '/ - name: centos/a \ \ \ ssh-authorized-keys:' /etc/cloud/cloud.cfg
  fi
  # XXX Must be changed for real installations
  sed -i -e '/   ssh-authorized-keys:/a \ \ \ \ - ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key' /etc/cloud/cloud.cfg
  /bin/rm -rf /var/lib/cloud/* > /dev/null 2>&1
fi

# Make sure rescue image is not built without a configuration change
echo dracut_rescue_image=no > /etc/dracut.conf.d/no-rescue.conf

# Finalize
truncate -s 0 /etc/resolv.conf
rm -f /var/lib/systemd/random-seed
restorecon -R /etc > /dev/null 2>&1 || :

# Clean
dnf -C clean all
/bin/rm -rf /etc/*- /etc/*.bak /root/* /tmp/* /var/tmp/*
/bin/rm -rf /var/cache/dnf/* /var/lib/dnf/repos/* /var/lib/dnf/yumdb/*
/bin/rm -rf /var/log/*debug /var/log/anaconda /var/lib/rhsm
%end
