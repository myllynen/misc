# RHEL 9 base / OpenStack / cloud example kickstart file
#
# Install:
# virt-install \
#   --connect qemu:///system --name test --virt-type kvm --arch x86_64 \
#   --vcpus 2 --cpu host-model --ram 2048 --os-variant rhel9.6 \
#   --boot uefi --boot useserial=on \
#   --boot loader=/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd,loader_ro=yes,loader_secure=yes \
#   --disk pool=default,format=qcow2,size=8 \
#   --network network=default --graphics vnc --sound none --noreboot \
#   --location /VirtualMachines/boot/rhel-9.6-x86_64-dvd.iso \
#   --initrd-inject /VirtualMachines/boot/ks/rhel-9-base.ks \
#   --extra-args "inst.ks=file:/rhel-9-base.ks inst.geoloc=0 inst.nosave=all ip=dhcp console=tty0 console=ttyS0,115200 net.ifnames.prefix=net quiet" \
#   --noautoconsole
#
# Post-process:
# 1) virt-sysprep --root-password password:foobar -a ./rhel.qcow2
# 2) virt-sparsify --in-place ./rhel.qcow2
# 3) qemu-img convert -c -p -O qcow2 ./rhel.qcow2 ./rhel-final.qcow2

cmdline
zerombr
clearpart --all --initlabel --disklabel gpt
bootloader --timeout 1 --append "console=tty0 console=ttyS0,115200 net.ifnames.prefix=net quiet"
part biosboot  --fstype biosboot --size 1
part /boot/efi --fstype efi      --size 63
part /boot     --fstype xfs      --size 1024
#part swap      --fstype swap     --size 1024
part /         --fstype xfs      --size 1024 --grow
selinux --enforcing
authselect select minimal without-nullok with-pamaccess
rootpw --plaintext foobar
#network --device net0 --bootproto dhcp --onboot yes --hostname test.example.com
#--noipv6
firewall --enabled --service ssh
firstboot --disabled
lang C.UTF-8
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
bind-utils
#cloud-init
#cloud-utils-growpart
glibc-langpack-en
glibc-minimal-langpack
#insights-client
man-pages
nano
NetworkManager-config-server
policycoreutils-python-utils
prefixdevname
psmisc
python3
python3-libselinux
setools-console
#sos
tar
#unzip
#vim-enhanced
yum-utils
zsh
zstd

# BIOS/UEFI cross-compatible image packages
#efibootmgr
#-flashrom
#grub2-efi-x64
#grub2-pc
#-mdadm
##parted
#shim-x64

# For security profile
#openscap
#openscap-scanner
#scap-security-guide

tuned

-a*firmware*
-dracut-config-rescue
-gawk-all-langpacks
-i*firmware*
-langpacks-*
-lib*firmware*
-linux-firmware
-n*firmware*
-NetworkManager-team
-NetworkManager-tui
-parted
-plymouth
-rhc*
-sqlite
-sssd*

# Ultra lean
#-audit
#-authselect*
#-e2fsprogs
#-firewalld
#-lshw
#-kernel-modules-extra
#-kexec-tools
#-man-db
#-rootfiles
#-sg3_utils*
#-tuned
%end

%post
# GRUB / console
#sed -i -e 's,GRUB_TERMINAL.*,GRUB_TERMINAL="serial console",' /etc/default/grub
#sed -i -e '/GRUB_SERIAL_COMMAND/d' -e '$ i GRUB_SERIAL_COMMAND="serial --speed=115200"' /etc/default/grub
#sed -i -e 's/console=tty0 //' -e 's/ console=ttyS0,115200//' /etc/default/grub
#grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-editenv - unset menu_auto_hide
systemctl enable serial-getty@ttyS0.service
#systemctl enable serial-getty@ttyS1.service
# NB. pam_securetty.so is disabled by default
#echo ttyS1 >> /etc/securetty

# BIOS/UEFI cross-compatibility
rm -f /boot/efi/EFI/redhat/grub.cfg.rpmsave
if [ -d /sys/firmware/efi ]; then
  test -b /dev/vda && disk=/dev/vda || disk=/dev/sda
  rpm -q grub2-pc > /dev/null 2>&1 && grub2-install --target=i386-pc $disk || :
  #rpm -q parted > /dev/null 2>&1 && parted $disk disk_set pmbr_boot off || :
fi

# Modules
echo blacklist pcspkr >> /etc/modprobe.d/blacklist.conf

# Networking
ipv6=no
sed -i -e '/cockpit/d' /etc/firewalld/zones/public.xml
rm -f /etc/firewalld/zones/public.xml.old

# IPv6
if [ "$ipv6" = "no" ]; then
  echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/50-ipv6.conf
  echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/50-ipv6.conf
  echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.d/50-ipv6.conf
  for netconf in $(ls -1 /etc/NetworkManager/system-connections/*.nmconnection); do
    sed -i -e '/^\[ipv6\]$/,/^\[/ s/method=.*/method=disabled/' $netconf
  done
  sed -i -e '/^::1/d' /etc/hosts
  echo "AddressFamily inet" > /etc/ssh/sshd_config.d/50-ipv6.conf
  sed -i -e 's,^OPTIONS=",OPTIONS="-4 ,g' -e 's, ",",' /etc/sysconfig/chronyd
  sed -i -e 's,^IPv6_rpfilter=yes,IPv6_rpfilter=no,' /etc/firewalld/firewalld.conf
  sed -i -e '/dhcpv6-client/d' /etc/firewalld/zones/public.xml
fi

# ssh/d
#sed -Ei -e 's,^(#|)PermitRootLogin .*,PermitRootLogin yes,' /etc/ssh/sshd_config
mkdir -m 0700 -p /root/.ssh
#echo "ssh-ed25519 ..." > /root/.ssh/authorized_keys
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

# Import Red Hat RPM GPG key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

# Remote execution directory if tmp dirs are noexec
mkdir -p -m 0700 /var/lib/exec

# Packages trimming
echo "%_install_langs en_US" > /etc/rpm/macros.install-langs-conf
#echo "%_excludedocs 1" > /etc/rpm/macros.excludedocs-conf
#echo "install_weak_deps=False" >> /etc/dnf/dnf.conf
#dnf -C -y remove linux-firmware > /dev/null 2>&1 || :

# Update to latest packages
#dnf -y update

# Services
systemctl disable dnf-makecache.timer nis-domainname.service remote-fs.target

# Watchdog
sed -i -e 's,^#RuntimeWatchdogSec=.*,RuntimeWatchdogSec=60s,' /etc/systemd/system.conf

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

# Remove machine identification and state
#for netdev in $(nmcli -t dev | cut -d: -f1 | grep -v lo); do
#  sed -i -e '/uuid=/d' /etc/NetworkManager/system-connections/$netdev.nmconnection
#  sed -i -e '/dhcp-/d' /etc/NetworkManager/system-connections/$netdev.nmconnection
#  sed -i -e '/origin/d' /etc/NetworkManager/system-connections/$netdev.nmconnection
#  sed -i -e '/timestamp/d' /etc/NetworkManager/system-connections/$netdev.nmconnection
#done
truncate -s 0 /etc/machine-id /etc/resolv.conf
/bin/rm -rf /etc/systemd/network/7* /etc/udev/rules.d/7* /etc/ssh/ssh_host_*
/bin/rm -rf /var/lib/systemd/random-seed

# Clear caches, files, and logs
/bin/rm -rf /root/* /tmp/* /tmp/.[a-zA-Z]* /var/tmp/*
/bin/rm -rf /etc/*- /etc/*.bak /etc/*~ /etc/sysconfig/*~
/bin/rm -rf /var/cache/dnf/* /var/lib/dnf/* /var/log/rhsm/*
/bin/rm -rf /var/lib/NetworkManager/* /var/lib/unbound/*.key
/bin/rm -rf /var/log/*debug /var/log/anaconda /var/log/dmesg*
/bin/rm -rf /var/lib/cloud/* /var/log/cloud-init*.log
/bin/rm -rf /var/lib/authselect/backups/*
#truncate -s 0 /var/log/cron /var/log/tuned/tuned.log
#truncate -s 0 /var/log/audit/audit.log /var/log/messages /var/log/secure
#truncate -s 0 /var/log/btmp /var/log/wtmp /var/log/lastlog

# Update initramfs
dracut -f --regenerate-all

# Create kdump initramfs for all kernels
for kver in $(rpm -q --qf "%{version}-%{release}.%{arch}\n" kernel); do
  sed -i -e "s,^KDUMP_KERNELVER=.*,KDUMP_KERNELVER=$kver," /etc/sysconfig/kdump
  kdumpctl rebuild
  sed -i -e 's,^KDUMP_KERNELVER=.*,KDUMP_KERNELVER="",' /etc/sysconfig/kdump
done

# Ensure everything is written to the disk
sync ; echo 3 > /proc/sys/vm/drop_caches ;
%end
