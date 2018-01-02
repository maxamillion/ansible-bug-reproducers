Memory profiling information from a run using the `mem_profile` execution
strategy

```
MEM change: 0.01171875 MiB cur: 1320.34765625 prev: 1320.34765625 (pid=50895)
strategy -- before add_tqm_variables
MEM change: 1345.75 MiB cur: 2666.09765625 prev: 2666.09765625 (pid=50895)
strategy -- after queue_task
```

Need the
[mem_profile](https://github.com/maxamillion/ansible/tree/mem_profile_strat_minimal)
strategy to execute this.