
# Using the cluster

The Kubernetes _API server_ can be accessed by using a `kubeconfig`
in `kubectl`. Copy the `admin.tar` file from the _Administration Dashboard_,
uncompress it and export the `KUBECONFIG` variable or use the `--kubeconfig`
flag.

For example:

```
$ scp -i ssh/id_docker root@`terraform output ip_dashboard`:admin.tar .
$ tar xvpf admin.tar
$ kubectl --kubeconfig=kubeconfig get nodes
```
