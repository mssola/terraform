# Kubernetes on OpenStack

This is a sample deployment of kubernetes on top of OpenStack. This is not using
Magnum, since we don't have it yet ;)

The deployment consists of:

  * salt server: used to configure all the nodes
  * etcd cluster: the number of nodes can be configured
  * kube-master
  * kube-minions: the number of nodes can be configured

The whole infrastructure can be deployed using [terraform](https://www.terraform.io).
A packaged version of terraform can be found on OBS inside of the
Virtualization:containers project.

## Cluster configuration

Some aspects of the cluster can be configured by using terraform
variables.

All the variables are defined inside of `variables.tf`.

There's no need to change the file, you can simply set them using
environment variables.

Examples:
```
$ export TF_VAR_name="value"
$ terraform <command>
```

For more information checkout [this](https://www.terraform.io/docs/configuration/variables.html)
section of terraform's documentation.

### Avoiding name clashes

By default all the VMs provisioned by terraform are going to be named in the
same way (eg: `kube-master`, `etcd1`, `etcd2`,...). This makes impossible for
multiple people to deploy a kubernetes cluster on the same cloud.

This can be solved by setting the `cluster_prefix` variable to something like
`flavio-`.

### Configuring the size of the etcd cluster

By default the etcd cluster is composed by 3 nodes. However it's possible to
change the default value by using the `etcd_cluster_size` variable.

### Configuring the number of k8s minions

By default the k8s cluster has 3 k8s minions. However it's possible to
change the default value by using the `kube_minions_size` variable.

## Deploying the cluster

Unfortunately there isn't yet a way to bring up the whole cluster with one
single command.

It's necessary to first create the infrastructure and then to configure the
machines via salt.

### Creating the infrastructure

First of all download your [OpenStack RC file](https://cloud.suse.de/project/access_and_security/api_access/openrc/).

Then load it:

```
$ source appliances.rc
```

and finally provision the whole infrastructure:

```
$ terraform plan # see what is going to happen
$ terraform apply # apply the operations
```

If you make changes to the default infrastructure you are encouraged to commit
the `terraform.tfstate` and `terraform.tfstate.backup` to git.

### Certificates

#### Generating the certificates automatically

You must generate certificates for your Kubernetes components in order to
use secure connections. You can run the certificates generation script
in the Salt master with:

    $ ssh -i ssh/id_docker root@`terraform output salt-fip` /srv/salt/certs/certs.sh

This will prepare the following certificates (that Salt will provision in
`/etc/kubernetes/ssl/kube-ca`):

- for each API server: the `ca.crt`, `apisserver.crt` and `apiserver.key`
- for each minion: the `ca.crt`, `minion.crt` and `minion.key`

#### Generating the certificates manually

##### Cluster Root CA

First, we need to create a new certificate authority which will
be used to sign the rest of our certificates.

    $ openssl genrsa -out ca.key 2048
    $ openssl req -x509 -new -nodes -key ca.key -days 10000 -out ca.crt -subj "/CN=kube-ca"

You need to store the CA keypair in a secure location for future use.

##### API Server Keypair

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

##### Minions Keypairs

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

##### Cluster Administrator Keypair

You can generate certificates for managing the cluster with `kubectl` from
a remote machine.

    $ openssl genrsa -out admin-key.pem 2048
    $ openssl req -new -key admin-key.pem -out admin.csr -subj "/CN=kube-admin"
    $ openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out admin.pem -days 365

### Running salt orchestrator

Once all the virtual machines are up and running it's time to configure them.

We are going to use the [salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner)
to implement that.

Just execute the following snippet:

```
# Connect to the remote salt server
$ ssh -i ssh/id_docker root@`terraform output salt-fip`
# Execute the orchestrator
# salt-run state.orchestrate orch.kubernetes
```

## Using the cluster

The kubernetes api-server is publicly available. It can be reached on port `8080`
of the floating IP associated to the `kube-master` node.

For example:

```
$ kubectl -s http://`terraform output kube-master-fip`:8080 get pods
```

There's however a more convenient way to use `kubelet`, we can use a dedicated
profile for this cluster. You can read
[here](https://coreos.com/kubernetes/docs/latest/configure-kubectl.html) how
it's possible to configure kubelet.

Inside of this project there's a `.envrc` file. This is a shell profile that
can be automatically be loaded by [direnv](http://direnv.net/). Once you install
`direnv` you won't have to type anything, just enter the directory and start
using `kubectl` without any special parameter.

You can install direnv from the [utilities](https://build.opensuse.org/package/show/utilities/direnv)
project. Note well, you will need to have `terraform` installed in order to
get everything working.
