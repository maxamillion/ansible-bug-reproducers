Run reproducer.sh (thanks @jctanner)


```
MEM change: 0.01171875 MiB cur: 1320.34765625 prev: 1320.34765625 (pid=50895)
strategy -- before add_tqm_variables
MEM change: 1345.75 MiB cur: 2666.09765625 prev: 2666.09765625 (pid=50895)
strategy -- after queue_task
```

```
========================================
MEM change: 569.3671875 MiB cur: 880.4765625 prev: 880.4765625 (pid=15278) strategy -- after _process_pending_results
> /home/mwoodson/git/ansible/lib/ansible/plugins/strategy/mem_profile.py(116)track_mem()
-> print('\n')
(Pdb) w
  /home/mwoodson/git/ansible/bin/ansible-playbook(106)<module>()
-> exit_code = cli.run()
  /home/mwoodson/git/ansible/lib/ansible/cli/playbook.py(122)run()
-> results = pbex.run()
  /home/mwoodson/git/ansible/lib/ansible/executor/playbook_executor.py(154)run()
-> result = self._tqm.run(play=play)
  /home/mwoodson/git/ansible/lib/ansible/executor/task_queue_manager.py(290)run()
-> play_return = strategy.run(iterator, play_context)
  /home/mwoodson/git/ansible/lib/ansible/plugins/strategy/mem_profile.py(161)run()
-> res = super(StrategyModule, self).run(iterator, play_context)
  /home/mwoodson/git/ansible/lib/ansible/plugins/strategy/linear.py(284)run()
-> results += self._process_pending_results(iterator, max_passes=max(1, int(len(self._tqm._workers) * 0.1)))
  /home/mwoodson/git/ansible/lib/ansible/plugins/strategy/mem_profile.py(193)_process_pending_results()
-> self.track_mem(msg='after _process_pending_results')
  /home/mwoodson/git/ansible/lib/ansible/plugins/strategy/mem_profile.py(155)track_mem()
-> prev_mem=self.prev_mem)
> /home/mwoodson/git/ansible/lib/ansible/plugins/strategy/mem_profile.py(116)track_mem()
-> print('\n')
```


Saw this at some point:

```
========================================
MEM change: 0.0234375 MiB cur: 91.78125 prev: 91.78125 (pid=104659) strategy -- after tqm_variables
fatal: [starter-us-west-1-node-compute-da0a2 -> localhost]: FAILED! => {
    "changed": false,
    "checksum": "8d1a77d5e1aedd8a6585b4625141ff0b7bf4de74"
}

MSG:

Aborting, target uses selinux but python bindings (libselinux-python) aren't installed!

fatal: [starter-us-west-1-node-compute-e4dab -> localhost]: FAILED! => {
    "changed": false,
    "checksum": "8d1a77d5e1aedd8a6585b4625141ff0b7bf4de74"
}

MSG:

Aborting, target uses selinux but python bindings (libselinux-python) aren't installed!



========================================
MEM change: 0.015625 MiB cur: 90.65625 prev: 90.65625 (pid=104659) strategy -- before add_tqm_variables


========================================
MEM change: 0.02734375 MiB cur: 90.68359375 prev: 90.68359375 (pid=104659) strategy -- after tqm_variables
An exception occurred during task execution. To see the full traceback, use -vvv. The error was: OSError: [Errno 12] Cannot allocate memory
fatal: [starter-us-west-1-node-compute-5dc78]: FAILED! => {}

MSG:

Unexpected failure during module execution.



========================================
MEM change: 0.05078125 MiB cur: 90.734375 prev: 90.734375 (pid=104659) strategy -- before add_tqm_variables


========================================
MEM change: 0.01171875 MiB cur: 90.74609375 prev: 90.74609375 (pid=104659) strategy -- after tqm_variables
fatal: [starter-us-west-1-node-compute-19b2e -> localhost]: FAILED! => {
    "changed": false,
    "checksum": "8d1a77d5e1aedd8a6585b4625141ff0b7bf4de74"
}

MSG:

Aborting, target uses selinux but python bindings (libselinux-python) aren't installed!

```

Memory consumption:

    * With import_role: 95.0546875
    * With include_role (deepcopy in task_result.py): 15064.7460938
    * With include_role (copy in task_result.py): 13683.5234375