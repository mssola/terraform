zypper -n in --no-recommends salt-master gcc python-devel libgit2-devel

cp -v /tmp/salt/master.d/* /etc/salt/master.d

systemctl enable salt-master
systemctl start salt-master
