
# Creating the infrastructure

The easiest way to configure your cluster is to use one of the included
`.profile` configuration files and overwrite the variables you need.
Then you can invoke the `k8s-setup` script with any of the commands
accepted by _Terraform_.

For example:

```
$ ./k8s-setup -F base-openstack.profile apply
```

(remember that, as a shortcut, `k8s-setup` invokes `terraform` with the
last argument, so this line generates a `k8s-setup.tf` and then invokes
`terraform apply`)

You can overwrite profile variables with the `-V` argument. For example:

```
$ ./k8s-setup -V kube_minions_size=6 -F base-openstack.profile apply
```

or with an additional configuration file:

```
$ echo "kube_minions_size=6" > local.profile
$ ./k8s-setup -F base-openstack.profile -F local.profile apply
```

If you want to review the generated `k8s-setup.tf` file, you can also
obtain a prettified version of this file with:

```
$ ./k8s-setup -F base-openstack.profile fmt
```

and then run any `terraform` command with this file.

After running `terraform apply` you will find an environment like this:

![](https://github.com/kubic-project/salt/raw/master/docs/k8s-before-orchestration.png)

Then you need to run the [Salt orchestration](salt.md) in order to install and
configure all the Kubernetes components.
