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
  * RHEL 7 base installation kickstart example
* [rhel-8-base.ks](rhel-8-base.ks)
  * RHEL 8 base installation kickstart example (see below)
* [rhel-8-init.yml](rhel-8-init.yml)
  * Ansible playbook to initialize a RHEL 8 system after installation
* [vagrant.ks](vagrant.ks)
  * Kickstart snippet to make Fedora/RHEL installation Vagrant-ready

## RHEL 8 Footprint Comparison

The following table illustrates RHEL 8 image footprint with various
installation options.

_Last updated for RHEL 8.0 Beta (later releases may have slightly
different characteristics)_.

1. RHEL Server default installation (using all defaults with the GUI
   installer)
2. Red Hat RHEL 8 Qcow2 image (from https://access.redhat.com/downloads/)
3. [rhel-8-base.ks](rhel-8-base.ks) based kickstart installation
4. [rhel-8-base.ks](rhel-8-base.ks) "ultra lean" installation
   (using __--excludedocs__ and other `%packages` options listed in the
   file, `firewalld` and `tuned` services disabled, using `network.service`
   instead of `NetworkManager`, all custom packages omitted)
5. [rhel-8-base.ks](rhel-8-base.ks) "ultra lean" with SELinux disabled

| Variant    |    1   |    2   |    3   |    4   |    5   |
|------------|:------:|:------:|:------:|:------:|:------:|
| RPMs       |   377  |   416  |   327  |   228  |   223  |
| Disk usage |  1.2G  |  1.1G  |  645M  |  469M  |  419M  |
| RAM usage  |  144M  |  123M  |  136M  |   80M  |   55M  |

## License

GPLv2+
