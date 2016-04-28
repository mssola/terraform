zypper -n in --no-recommends salt-minion gcc python-devel

cp -v /tmp/salt/minion.d/* /etc/salt/minion.d
cp -v /tmp/salt/grains /etc/salt/

systemctl enable salt-minion
systemctl start salt-minion

exit 0

TIMEOUT=90
COUNT=0
while [ ! -f /etc/salt/pki/minion/minion_master.pub ]; do
    echo "Waiting for salt minion to start"
    if [ "$COUNT" -ge "$TIMEOUT" ]; then
        echo "minion_master.pub not detected by timeout"
        exit 1
    fi
    sleep 5
    COUNT=$((COUNT+5))
done

echo "Calling highstate"
salt-call state.highstate
