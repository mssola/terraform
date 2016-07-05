
# Generating the certificates automatically

You must generate certificates for your Kubernetes components in order to
use secure connections. You can run the certificates generation script
in the Salt master with:

    $ ssh -i ssh/id_docker root@`terraform output salt-fip` /srv/salt/certs/certs.sh

This will prepare the following certificates (that Salt will provision in
`/etc/kubernetes/ssl/kube-ca`):

- for each API server: the `ca.crt`, `apisserver.crt` and `apiserver.key`
- for each minion: the `ca.crt`, `minion.crt` and `minion.key`

# Generating the certificates manually

## Cluster Root CA

First, we need to create a new certificate authority which will
be used to sign the rest of our certificates.

    $ openssl genrsa -out ca.key 2048
    $ openssl req -x509 -new -nodes -key ca.key -days 10000 -out ca.crt -subj "/CN=kube-ca"

You need to store the CA keypair in a secure location for future use.

## API Server Keypair

This is a minimal openssl config which will be used when creating the
API server certificate. We need to create a configuration file since
some of the options we need to use can’t be specified as flags. Create
`apiserver.cnf` on your local machine and replace `${K8S_SERVICE_IP}`
and `${MASTER_HOST}`

    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    subjectAltName = @alt_names
    [alt_names]
    DNS.1 = kubernetes
    DNS.2 = kubernetes.default
    DNS.3 = kubernetes.default.svc
    DNS.4 = kubernetes.default.svc.cluster.local
    IP.1 = ${K8S_SERVICE_IP}
    IP.2 = ${MASTER_HOST}

If deploying multiple master nodes in an HA configuration, you may need
to add more TLS `subjectAltNames` (SANs). Proper configuration of SANs in
each certificate depends on how worker nodes and kubectl users contact the
master nodes: directly by IP address, via load balancer, or by resolving
a DNS name.

Example:

    DNS.5 = ${MASTER_DNS_NAME}
    IP.3 = ${MASTER_IP}
    IP.4 = ${MASTER_LOADBALANCER_IP}

Using the above `apiserver.cnf`, create the API server keypair:

    $ openssl genrsa -out apiserver.key 2048
    $ openssl req -new -key apiserver.key -out apiserver.csr -subj "/CN=kube-apiserver" -config apiserver.cnf
    $ openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out apiserver.crt -days 365 -extensions v3_req -extfile apiserver.cnf

Then copy the certificate (`apiserver.crt`) and the private key (`apiserver.key`)
to `/etc/kubernetes/ssl/kube-ca` in the API server.

## Minions Keypairs

This procedure generates a unique TLS certificate for every Kubernetes
minion in your cluster. While unique certificates are less convenient
to generate and deploy, they do provide stronger security assurances and the
most portable installation experience across multiple cloud-based and
on-premises Kubernetes deployments.

We will use a common openssl configuration file for all minions. The certificate
output will be customized per worker based on environment variables used in
conjunction with the configuration file. Create the file `minion.cnf` on
your local machine with the following contents.

    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    subjectAltName = @alt_names
    [alt_names]
    IP.1 = $ENV::MINION_IP

Run the following set of commands once for every minion in your cluster.
Replace `MINION_FQDN` and `MINION_IP` in the following commands with
the correct values for each node. If the node does not have a routeable hostname,
set `MINION_FQDN` to a unique, per-node placeholder name like `kube-minion-1`,
`kube-minion-2` and so on.

    $ openssl genrsa -out minion.key 2048
    $ MINION_IP=${MINION_IP} openssl req -new -key minion.key -out minion.csr -subj "/CN=${MINION_FQDN}" -config minion.cnf
    $ MINION_IP=${MINION_IP} openssl x509 -req -in minion.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out minion.crt -days 365 -extensions v3_req -extfile minion.cnf

Then copy the certificate (`minion.crt`) and the private key (`minion.key`)
to `/etc/kubernetes/ssl/kube-ca` in the minion.

## Cluster Administrator Keypair

You can generate certificates for managing the cluster with `kubectl` from
a remote machine.

    $ openssl genrsa -out admin-key.pem 2048
    $ openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
    $ openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.pem -days 365
