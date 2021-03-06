# Miscellaneous stuff

[![License: GPLv2](https://img.shields.io/badge/license-GPLv2-brightgreen.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-brightgreen.svg)](https://www.gnu.org/licenses/gpl-3.0)

Nothing but random stuff here.

## Contents

* [ansible.cfg](ansible.cfg)
  * Example Ansible configuration with optimizations
* [fedora-init.yml](fedora-init.yml)
  * Ansible playbook to initialize a Fedora system after installation
* [qcow2-to-box](qcow2-to-box)
  * A simple script to create Vagrant boxes from Qcow2 images
* [rhel-7-base.ks](rhel-7-base.ks)
  * RHEL 7 base installation kickstart example (see below)
* [rhel-8-base.ks](rhel-8-base.ks)
  * RHEL 8 base installation kickstart example (see below)
* [rhel-8-init.yml](rhel-8-init.yml)
  * Ansible playbook to initialize a RHEL 8 system after installation
* [vagrant.ks](vagrant.ks)
  * Kickstart snippet to make Fedora/RHEL installation Vagrant-ready

## RHEL 7 Footprint Comparison

The following table illustrates RHEL 7 image footprint with various
installation options.

_Last updated for RHEL 7.6 Server (later releases may have slightly
different characteristics)_.

1. RHEL Server default installation (using all defaults with the GUI
   installer)
2. Red Hat RHEL 7 Qcow2 image (from https://access.redhat.com/downloads/)
   (has no `firewalld` running)
3. [rhel-7-base.ks](rhel-7-base.ks) based kickstart installation
4. "Ultra lean" installation using [rhel-7-base.ks](rhel-7-base.ks)
   with __--excludedocs__ and other `%packages` options listed,
   all additional packages listed in `%packages` section omitted,
   `firewalld`, `kdump`, and `tuned` services disabled, using
   `network.service` and `dhclient` instead of `NetworkManager`,
   `auth` and `firewall` directives omitted
   (due to depending on excluded packages)
5. "Ultra lean" installation with also SELinux disabled

NB. The _linux-firmware_ package takes 176M on disk if installed, it is
removed by the kickstart `%post` script but in case of a kernel update
it will be installed again, even if not needed on VMs.

| Variant    |    1   |    2   |    3   |    4   |    5   |
|------------|:------:|:------:|:------:|:------:|:------:|
| RPMs       |   342  |   345  |   267  |   198  |   194  |
| Disk usage | 1176M  |  950M  |  581M  |  421M  |  400M  |
| RAM usage  |  102M  |   76M  |   90M  |   43M  |   40M  |

## RHEL 8 Footprint Comparison

The following table illustrates RHEL 8 image footprint with various
installation options.

_Last updated for RHEL 8.0 (later releases may have slightly different
characteristics)_.

See also [this RFE](https://bugzilla.redhat.com/show_bug.cgi?id=1660122)
for comments about the official RHEL 8 Qcow2 image.

1. RHEL Server default installation (using all defaults with the GUI
   installer for a Minimal installation)
2. Red Hat RHEL 8 Qcow2 image (from https://access.redhat.com/downloads/)
   (has no `firewalld` running)
3. [rhel-8-base.ks](rhel-8-base.ks) based kickstart installation
4. "Ultra lean" installation using [rhel-8-base.ks](rhel-8-base.ks)
   with __--excludedocs__ and other `%packages` options listed,
   all additional packages listed in `%packages` section omitted,
   `firewalld`, `kdump`, and `tuned` services disabled, using
   `network.service` and `dhclient` instead of `NetworkManager`,
   `authselect` and `firewall` directives omitted
   (due to depending on excluded packages)
5. "Ultra lean" installation with also SELinux disabled
   (see https://bugzilla.redhat.com/show_bug.cgi?id=1660142)

NB. The _linux-firmware_ package takes 291M on disk if installed, it
is removed by the kickstart `%post` script but in case of kernel update
it will be installed again, even if not needed on VMs.

See also [this RFE](https://bugzilla.redhat.com/show_bug.cgi?id=1657204)
for discussion to possibly change RHEL firmware packages as [weak
dependencies](https://fedoraproject.org/wiki/Packaging:WeakDependencies)
for RHEL 8 kernel.

| Variant    |    1   |    2   |    3   |    4   |    5   |
|------------|:------:|:------:|:------:|:------:|:------:|
| RPMs       |   406  |   437  |   330  |   232  |   226  |
| Disk usage | 1491M  | 1279M  |  709M  |  515M  |  463M  |
| RAM usage  |  179M  |  148M  |  161M  |  103M  |   70M  |

## License

GPLv2+
