# Running Salt orchestrator

Unfortunately there isn't yet a way to bring up the whole cluster with one
single command: it's necessary to first create the infrastructure with
_Terraform_ and then to provision and configure the machines with _Salt_.

So once all the virtual machines are up and running it's time to install
software and configure them. Our Salt scripts are located [here](http://github.com/kubic-project/salt),
where you can find all the documentation about the provisioning process and
the [Salt orchestration](https://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#orchestrate-runner).

You can trigger the orchestration on the Administration Dashboard with
the following `ssh` command:

```
$ ssh -i ssh/id_docker root@`terraform output ip_dashboard` \
         bash /tmp/provision/admin/provision.sh --finish
```

After the orchestration you will find an environment like this:

![](https://github.com/kubic-project/salt/raw/master/docs/k8s-after-orchestration.png)

Then follow the instructions given by the provisioning script.

Notes:

* the certificate generated for the API server includes the list of IPs
automatically detected by provisioning script. However, this is not enough
in some cases when the API server will be accessed at some other IP
(for example, when the server is behind a NAT or when a _floating IP_ is
assigned to it in a _OpenStack_ cluster). In those cases, you should
specify that IP in with `--extra-api-ip <IP>`.
