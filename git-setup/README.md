# Quick Git Setup Guide

[![License: GPLv2](https://img.shields.io/badge/license-GPLv2-brightgreen.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html)
[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-brightgreen.svg)](https://www.gnu.org/licenses/gpl-3.0)

Basic steps to setup local (test) Git repo infra.

## Guide to Setup Local (Test) Git Repo Infra

The following has been tested on RHEL 8 02/2022, it may or may not work
on other distributions or even on RHEL 8 anymore, you have been warned!

Everyone is allowed to clone read-only repositories over the Git and
HTTP protocols, push (write) access is allowed over SSH only. The setup
expects mostly small and trusted environment so further securing and
design review is strongly recommended for larger and hostile
environments.

### Install Packages

```
yum install -y firewalld git git-daemon gitweb highlight httpd
```

### Configure and Enable Services

The _git_ and _http_ services are enabled below to allow read-only
cloning over the Git and HTTP protocols, however they are optional.

```
systemctl enable --now firewalld.service
systemctl enable --now httpd.service
systemctl enable --now git.socket
firewall-cmd --zone=public --add-service=http
firewall-cmd --zone=public --add-service=git
firewall-cmd --runtime-to-permanent
```

### Configure GitWeb

Below is basic example of GitWeb customization:

```
echo 'our $site_name = "Intranet Git Repos";' >> /etc/gitweb.conf
echo 'our $projects_list = "/var/lib/git/conf/gitweb-projects";' >> /etc/gitweb.conf
echo "\$feature{'highlight'}{'default'} = [1];" >> /etc/gitweb.conf
echo '<p>Welcome to Intranet Git Repos!</p>' > /var/www/git/indextext.html
```

Optionally, disable the search box on the GitWeb front page. This is
currently not configurable so _gitweb_ package updates will overwrite
this change.

```
sed -i -e 's,git_project_search_form(,#git_project_search_form(,' /var/www/git/gitweb.cgi
```

### Add git User and Create Server git Directory Structure

```
groupadd -g 4441 git
mkdir -p /var/lib/git/conf
touch /var/lib/git/conf/gitweb-projects
chown -R root:git /var/lib/git
chmod 2775 /var/lib/git /var/lib/git/conf
chmod 0664 /var/lib/git/conf/gitweb-projects
restorecon -Rv /var/lib/git
```

### Configure httpd

Only the last section (the default on RHEL 8) is needed if cloning over
HTTP is not allowed.

```
cat << 'EOF' > /etc/httpd/conf.d/gitweb.conf
# Basic configuration
#SetEnv GIT_HTTP_EXPORT_ALL
SetEnv GIT_PROJECT_ROOT /var/lib/git
#ScriptAlias /git/ /usr/libexec/git-core/git-http-backend/

# Allow executing git-http-backend
<Directory /usr/libexec/git-core>
  <Files "git-http-backend">
    Options +ExecCGI
    Require all granted
  </Files>
</Directory>

# Serve static files directly
AliasMatch ^/git/(.*/objects/[0-9a-f]{2}/[0-9a-f]{38})$          /var/lib/git/$1
AliasMatch ^/git/(.*/objects/pack/pack-[0-9a-f]{40}.(pack|idx))$ /var/lib/git/$1

# Serve repository objects with Git HTTP backend
ScriptAliasMatch \
        "(?x)^/git/(.*/(HEAD | \
                        info/refs | \
                        objects/info/[^/]+ | \
                        git-(upload|receive)-pack))$" \
        /usr/libexec/git-core/git-http-backend/$1

# Serve browsers with GitWeb
Alias /git /var/www/git

<Directory /var/www/git>
  Options +ExecCGI
  AddHandler cgi-script .cgi
  DirectoryIndex gitweb.cgi
</Directory>
EOF
systemctl restart httpd.service
```

### Configure Users

Each user allowed to push over SSH must be added to _git_ group:

```
usermod -a -G git developer1
usermod -a -G git developer2
```

### Creating New Repositories

Use the [newrepo](newrepo) script to setup new repositories:

```
./newrepo testrepo
```

## License

GPLv2+
