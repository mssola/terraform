zypper -n in --no-recommends salt-master gcc python-devel libgit2-devel

cp -v /tmp/salt/master.d/* /etc/salt/master.d

# fix some permissions and missing dirs
[ -f /srv/salt/certs/certs.sh] && chmod 755 /srv/salt/certs/certs.sh
[ -d /srv/files ] || mkdir -p /srv/files

systemctl enable salt-master
systemctl start salt-master
