### Creating the libvirt infrastructure

* First you must install the libvirt Terraform provider.
* Then check the values of some important variables in `variables.tf`,
in particular:
  * the `storage_pool` must exist
  * there must be a `base_volume` image already uploaded in that pool
You can override these values by defining environment variables (ie,
`export TF_VAR_storage_pool=default`).
* Provision the infrastructure with:

```
$ terraform plan     # see what is going to happen
$ terraform apply    # apply the operations
```
