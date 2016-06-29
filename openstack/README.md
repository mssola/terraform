### Creating the OpenStack infrastructure

* First of all download your [OpenStack RC v2 file](https://cloud.suse.de/project/access_and_security/api_access/openrc/). Then
load it with:
```
$ source openrc.sh
```
* Then make sure there is a _ssh key_ in OpenStack with the same name as `variables.tf:key_pair`
(by default, `docker`). You must create it with the contents of the `<top_dir>/ssh/id_<name>.pub`
if it does not exist.
* Provision the infrastructure with:

```
$ terraform plan     # see what is going to happen
$ terraform apply    # apply the operations
```
