# RHEL 9 base / OpenStack / cloud example kickstart file
#
# Install:
# virt-install \
#   --connect qemu:///system --name test --virt-type kvm --arch x86_64 \
#   --vcpus 2 --cpu host --ram 2048 --os-type linux --os-variant rhel9.0 \
#   --disk pool=default,format=qcow2,cache=none,io=native,size=8 \
#   --network network=default --graphics vnc --sound none --noreboot \
#   --location /VirtualMachines/boot/rhel-9.0-x86_64-dvd.iso \
#   --initrd-inject /VirtualMachines/boot/ks/rhel-9-base.ks \
#   --extra-args "ip=dhcp inst.ks=file:/rhel-9-base.ks inst.geoloc=0 inst.nosave=all console=tty0 console=ttyS0,115200 net.ifnames.prefix=net ipv6.disable=0 quiet systemd.show_status=yes" \
#   --noautoconsole
#
# Post-process:
# 1) virt-sysprep --root-password password:foobar -a ./rhel.qcow2
# 2) virt-sparsify --in-place ./rhel.qcow2
# 3) qemu-img convert -c -p -O qcow2 ./rhel.qcow2 ./rhel-final.qcow2

cmdline
zerombr
clearpart --all --initlabel --disklabel gpt
bootloader --timeout 1 --append "console=tty0 console=ttyS0,115200 net.ifnames.prefix=net ipv6.disable=0 quiet systemd.show_status=yes"
reqpart
#part /boot --fstype xfs --asprimary --size 1024
#part swap --fstype swap --asprimary --size 1024
part / --fstype xfs --asprimary --size 1024 --grow
selinux --enforcing
authselect --useshadow --passalgo sha512
rootpw --plaintext foobar
#network --device net0 --bootproto dhcp --onboot yes --hostname test.example.com
#--noipv6
firewall --enabled --service ssh
firstboot --disabled
lang en_US.UTF-8
timezone --utc Europe/Helsinki
timesource --ntp-server time.cloudflare.com
keyboard fi
services --enabled tuned
poweroff

#%addon com_redhat_oscap
#content-type = scap-security-guide
#profile = xccdf_org.ssgproject.content_profile_cis_server_l1
#%end

# Options must be kept in sync with the below Packages - trimming section
%packages --inst-langs en_US
# --excludedocs
# --exclude-weakdeps
# --ignoremissing
# --nocore
bash-completion
#bind-utils
bzip2
#cloud-init
#cloud-utils-growpart
#insights-client
# TBR
kbd-legacy
man-pages
#mlocate
nano
#pciutils
policycoreutils-python-utils
python3-libselinux
setools-console
#sos
#strace
tar
#tcpdump
#telnet
#tmux
tuned
#unzip
util-linux-user
yum-utils
zsh

# For security profile
#aide
#openscap
#openscap-scanner
#scap-security-guide

-a*firmware*
-dracut-config-rescue
-i*firmware*
-lib*firmware*
-NetworkManager-team
-NetworkManager-tui
-parted
-plymouth
-sqlite
-sssd*
#-subs*

# Ultra lean
#-audit
#-authselect*
#-e2fsprogs
#-firewalld
#-lshw
#-kexec-tools
#-langpacks-*
#-man-db
#-rootfiles
#-sg3_utils*
#-tuned
%end

%post --erroronfail
# GRUB / console
#sed -i -e 's,GRUB_TERMINAL.*,GRUB_TERMINAL="serial console",' /etc/default/grub
#sed -i -e '/GRUB_SERIAL_COMMAND/d' -e '$ i GRUB_SERIAL_COMMAND="serial --speed=115200"' /etc/default/grub
#sed -i -e 's/console=tty0 //' -e 's/ console=ttyS0,115200//' /etc/default/grub
#grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-editenv - unset menu_auto_hide
systemctl enable serial-getty@ttyS0.service
#systemctl enable serial-getty@ttyS1.service
# NB. pam_securetty.so is disabled by default on RHEL 9
#echo ttyS1 >> /etc/securetty

# Modules
echo blacklist pcspkr >> /etc/modprobe.d/blacklist.conf

# Networking
#netuuid=$(uuidgen)
#sed -i -e "s,^uuid=.*,uuid=$netuuid," /etc/NetworkManager/system-connections/net0.nmconnection

# IPv6
grep -q ipv6.disable=1 /etc/default/grub && ipv6=no || ipv6=yes
if [ "$ipv6" = "no" ]; then
  sed -i -e '/^::1/d' /etc/hosts
  sed -i -e 's,^OPTIONS=",OPTIONS="-4 ,g' -e 's, ",",' /etc/sysconfig/chronyd
  sed -i -e 's,^IPv6_rpfilter=yes,IPv6_rpfilter=no,' /etc/firewalld/firewalld.conf
fi

# ssh/d
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

# Packages - trimming
echo "%_install_langs en_US" > /etc/rpm/macros.install-langs-conf
#echo "%_excludedocs 1" > /etc/rpm/macros.excludedocs-conf
#echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
#dnf -C -y remove linux-firmware > /dev/null 2>&1 || :

# Packages - EPEL
#dnf -y install epel-release

# Packages - update
#dnf -y update
#if [ $(rpm -q kernel | wc -l) -gt 1 ]; then
#  dnf remove -C --oldinstallonly -y || :
#fi

# Services
systemctl disable dnf-makecache.timer nis-domainname.service remote-fs.target

# Watchdog
sed -i -e 's,^#RuntimeWatchdogSec=0,RuntimeWatchdogSec=60s,' /etc/systemd/system.conf

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

# Remove machine identification and state
truncate -s 0 /etc/machine-id /etc/resolv.conf
/bin/rm -rf /etc/systemd/network/7* /etc/udev/rules.d/7* /etc/ssh/ssh_host_*
/bin/rm -rf /var/lib/systemd/random-seed

# Clear caches, files, and logs
/bin/rm -rf /root/* /tmp/* /var/tmp/*
/bin/rm -rf /etc/*- /etc/*.bak /etc/*~ /etc/sysconfig/*~
/bin/rm -rf /var/cache/dnf/* /var/cache/yum/*
/bin/rm -rf /var/lib/dnf/* /var/lib/yum/repos/* /var/lib/yum/yumdb/*
/bin/rm -rf /var/log/*debug /var/log/anaconda /var/log/dmesg*
#truncate -s 0 /var/log/audit/audit.log /var/log/messages /var/log/secure
#truncate -s 0 /var/log/btmp /var/log/wtmp /var/log/lastlog

# Update initramfs
dracut -f --regenerate-all

# Ensure everything is written to the disk
sync ; echo 3 > /proc/sys/vm/drop_caches ;
%end
