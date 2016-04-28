## Running salt orchestrator

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
