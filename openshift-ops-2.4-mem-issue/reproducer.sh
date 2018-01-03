#!/bin/bash

mkdir -p strategy_plugins
mkdir -p roles 

# roles are in a nested dir from a separate tools repo
if [ ! -d openshift-tools ]; then
    git clone https://github.com/openshift/openshift-tools
fi
if [ ! -s roles/tools_roles ]; then
    ln -s $(pwd)/openshift-tools/ansible/roles roles/tools_roles
fi

cat << EOF > test.sh
SSH_AUTH_SOCK=0
VERSION=\$(ansible --version | head -n1 | awk '{print \$2}')
ansible-playbook -vvvv -i inventory.py site.yml
RC=$?
exit $RC
EOF
chmod +x test.sh

cat << EOF > inventory.py
#!/usr/bin/env python

import json
import os

GROUPCOUNT=int(os.environ.get('GROUPCOUNT', 11))
HOSTCOUNT=int(os.environ.get('HOSTCOUNT', 101))
VARCOUNT=int(os.environ.get('VARCOUNT', 500))

INV = {}
INV['_meta'] = {'hostvars': {}}

groups = []
for x in range(0, GROUPCOUNT):
    groups.append('group-' + str(x))
hosts = ['host-' + str(x) for x in range(0, HOSTCOUNT)]

for idx, group in enumerate(groups):
    INV[group] = {}
    INV[group]['children'] = []
    INV[group]['vars'] = {}
    INV[group]['hosts'] = []

_groups = groups[:]
for host in hosts:
    if not _groups:
        _groups = groups[:]
    groupname = _groups[0]
    _groups.remove(groupname)
    INV[groupname]['hosts'].append(host)

for host in hosts:
    INV['_meta']['hostvars'][host] = {}
    INV['_meta']['hostvars'][host]['ansible_connection'] = 'local'
    for x in range(0, VARCOUNT):
        vkey = 'var' + str(x)
        INV['_meta']['hostvars'][host][vkey] = x


print json.dumps(INV, indent=2)
EOF
chmod +x inventory.py


cat << EOF > site.yml
- hosts: all
  strategy: mem_profile
  #strategy: mem_profile_minimal
  connection: local
  gather_facts: False
  #serial: 1
  #roles:
  #    - tools_roles/lib_repoquery
  post_tasks:
      #- include_role:
      #- import_role:
      - include_role:
          name: tools_roles/lib_repoquery
        #static: True
      #- repoquery:
      #    name: yum
      #- stat:
      #      path: /etc/passwd
EOF


cat << EOF > strategy_plugins/mem_profile_minimal.py
# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import os

from ansible.plugins.strategy.linear import StrategyModule as LinearStrategyModule

#import objgraph
import memory_profiler as mem_profile

DOCUMENTATION = '''
    strategy: mem_profile
    short_description: take some memory/objgraph info
    description:
        - Task execution is 'linear' but controlled by an interactive debug session.
    version_added: "2.5"
    author: Adrian Likins
'''

try:
    from __main__ import display
except ImportError:
    from ansible.utils.display import Display
    display = Display()


# from objgraph.py module Marius Gedminas, MIT lic
def show_table(stats):
    if not stats:
        return

    width = max(len(name) for name, count in stats)
    for name, count in stats:
        print('%-*s %i' % (width, name, count))


def filter_obj(obj):
    try:
        if not obj.__class__.__module__.startswith('ansible'):
            return False
    except Exception as e:
        print(e)
    return True


def extra_info_repr(obj):
    '''Add the obj repr to extra_info for ansible.* types'''
    if not obj.__class__.__module__.startswith('ansible'):
        return None

    try:
        return repr(obj)
    except Exception as e:
        print(e)

    return None


def extra_info_id(obj):
    '''return the hex obj id as extra_info'''

    return hex(id(obj))


def show_common_ansible_types(limit=None):
    print('\nmost common ansible types:')
#    common = objgraph.most_common_types(shortnames=False, limit=limit)
    ans_stats = [x for x in common if x[0].startswith('ansible') and x[1] > 1]
    show_table(ans_stats)


# TODO/FIXME: make decorator
def track_mem(msg=None, pid=None, call_stack=None, subsystem=None, prev_mem=None):
    if pid is None:
        pid = os.getpid()

    subsystem = subsystem or 'generic'

    mem_usage = mem_profile.memory_usage(-1, timestamps=True)
    delta = 0
    new_mem = 0
    for mems in mem_usage:
        # TODO/FIXME: just print this for now
        new_mem = mems[0]
        delta = new_mem - prev_mem

        prev_mem = new_mem

    verbose = False
    if delta > 0 or verbose:
        print('\n')
        print('='*40)
        print('MEM change: %s MiB cur: %s prev: %s (pid=%s) %s -- %s' %
              (delta, new_mem, prev_mem, pid, subsystem, msg))

        #print('new objects:')
        #objgraph.show_growth(limit=30, shortnames=False)

        #show_common_ansible_types(limit=2000)
        print('\n')

    import q; q(prev_mem,new_mem)
    return prev_mem


def show_refs(filename=None, objs=None, max_depth=5, max_objs=None):

    filename = filename or "mem-profile-default"
    refs_full_fn = "%s-refs.png" % filename
    backrefs_full_fn = "%s-backrefs.png" % filename

    objs = objs or []
    if max_objs:
        objs = objs[:max_objs]

    #objgraph.show_refs(objs,
    #                   filename=refs_full_fn,
    #                   refcounts=True,
    #                   extra_info=extra_info_id,
    #                   shortnames=False,
    #                   max_depth=max_depth)
#
#    objgraph.show_backrefs(objs,
#                           refcounts=True,
#                           shortnames=False,
#                           extra_info=extra_info_id,
#                           filename=backrefs_full_fn,
#                           max_depth=max_depth)


class StrategyModule(LinearStrategyModule):
    def __init__(self, tqm):
        super(StrategyModule, self).__init__(tqm)
        self.prev_mem = 0
        self.track_mem(msg='in __init__')

    def track_mem(self, msg=None, pid=None, call_stack=None, subsystem=None):
        subsystem = subsystem or 'strategy'
        self.prev_mem = track_mem(msg=msg, pid=pid, call_stack=call_stack, subsystem=subsystem,
                                  prev_mem=self.prev_mem)
        return self.prev_mem

    # FIXME: base Strategy.run has a result kwarg, but lineary does not
    def run(self, iterator, play_context, result=0):
        self.track_mem(msg='before run')
        res = super(StrategyModule, self).run(iterator, play_context)
        self.track_mem(msg='after run')

        #show_common_ansible_types()

##        # example of dumping graphviz dot/pngs for ref graph of some objs
#        tis = objgraph.by_type('ansible.playbook.task_include.TaskInclude')
#        show_refs(filename='task_include_refs', objs=tis, max_depth=6, max_objs=1)

        return res

    def add_tqm_variables(self, vars, play):
        self.track_mem(msg='before add_tqm_variables')
        res = super(StrategyModule, self).add_tqm_variables(vars, play)
        self.track_mem(msg='after tqm_variables')
        return res

    def _queue_task(self, host, task, task_vars, play_context):
        self.track_mem(msg='before queue_task')
        res = super(StrategyModule, self)._queue_task(host, task, task_vars, play_context)
        self.track_mem(msg='after queue_task')
        return res

    def _load_included_file(self, included_file, iterator, is_handler=False):
        self.track_mem(msg='before _load_included_file')
        res = super(StrategyModule, self)._load_included_file(included_file, iterator, is_handler=is_handler)
        self.track_mem(msg='after _load_included_file')
        return res

    def _process_pending_results(self, iterator, one_pass=False, max_passes=None):
        self.track_mem(msg='before _process_pending_results')
        res = super(StrategyModule, self)._process_pending_results(iterator, one_pass, max_passes)
        self.track_mem(msg='after _process_pending_results')
        return res
EOF


cat << EOF > strategy_plugins/mem_profile.py
# This file is part of Ansible
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import gc
import os
import sys

from ansible.plugins.strategy.linear import StrategyModule as LinearStrategyModule
from ansible.inventory.group import Group
from ansible.inventory.host import Host

import objgraph
import memory_profiler as mem_profile

DOCUMENTATION = '''
    strategy: mem_profile
    short_description: take some memory/objgraph info
    description:
        - Task execution is 'linear' but controlled by an interactive debug session.
    version_added: "2.5"
    author: Adrian Likins
'''

try:
    from __main__ import display
except ImportError:
    from ansible.utils.display import Display
    display = Display()


# from objgraph.py module Marius Gedminas, MIT lic
def show_table(stats):
    if not stats:
        return

    width = max(len(name) for name, count in stats)
    for name, count in stats:
        print('%-*s %i' % (width, name, count))


def filter_obj(obj):
    try:
        if not obj.__class__.__module__.startswith('ansible'):
            return False
    except Exception as e:
        print(e)
    return True


def extra_info_repr(obj):
    '''Add the obj repr to extra_info for ansible.* types'''
    if not obj.__class__.__module__.startswith('ansible'):
        return None

    try:
        return repr(obj)
    except Exception as e:
        print(e)

    return None


def extra_info_id(obj):
    '''return the hex obj id as extra_info'''

    return hex(id(obj))


def show_common_ansible_types(limit=None):
    print('\nmost common ansible types:')
    common = objgraph.most_common_types(shortnames=False, limit=limit)
    ans_stats = [x for x in common if x[0].startswith('ansible') and x[1] > 1]
    show_table(ans_stats)


# TODO/FIXME: make decorator
def track_mem(msg=None, pid=None, call_stack=None, subsystem=None, prev_mem=None):
    if pid is None:
        pid = os.getpid()

    subsystem = subsystem or 'generic'

    mem_usage = mem_profile.memory_usage(-1, timestamps=True)
    delta = 0
    new_mem = 0
    for mems in mem_usage:
        # TODO/FIXME: just print this for now
        new_mem = mems[0]
        delta = new_mem - prev_mem

        prev_mem = new_mem

    verbose = False
    if delta > 0 or verbose:
        print('\n')
        print('='*40)
        print('MEM change: %s MiB cur: %s prev: %s (pid=%s) %s -- %s' %
              (delta, new_mem, prev_mem, pid, subsystem, msg))

        print('new objects:')
        objgraph.show_growth(limit=10, shortnames=False)

        show_common_ansible_types(limit=10)
        print('\n')

    import q; q(prev_mem,new_mem)
    if new_mem > 500 or prev_mem > 500:
        objs = [x for x in gc.get_objects() if sys.getrefcount(x) > 0]
        objs = [x for x in objs if isinstance(x, (Group, Host))]
        hosts = [x for x in objs if isinstance(x, Host)]
        groups = [x for x in objs if isinstance(x, Group)]
        import epdb; epdb.st()

    return prev_mem


def show_refs(filename=None, objs=None, max_depth=5, max_objs=None):

    filename = filename or "mem-profile-default"
    refs_full_fn = "%s-refs.png" % filename
    backrefs_full_fn = "%s-backrefs.png" % filename

    objs = objs or []
    if max_objs:
        objs = objs[:max_objs]

    objgraph.show_refs(objs,
                       filename=refs_full_fn,
                       refcounts=True,
                       extra_info=extra_info_id,
                       shortnames=False,
                       max_depth=max_depth)

    objgraph.show_backrefs(objs,
                           refcounts=True,
                           shortnames=False,
                           extra_info=extra_info_id,
                           filename=backrefs_full_fn,
                           max_depth=max_depth)


class StrategyModule(LinearStrategyModule):
    def __init__(self, tqm):
        super(StrategyModule, self).__init__(tqm)
        self.prev_mem = 0
        self.track_mem(msg='in __init__')

    def track_mem(self, msg=None, pid=None, call_stack=None, subsystem=None):
        subsystem = subsystem or 'strategy'
        self.prev_mem = track_mem(msg=msg, pid=pid, call_stack=call_stack, subsystem=subsystem,
                                  prev_mem=self.prev_mem)
        return self.prev_mem

    # FIXME: base Strategy.run has a result kwarg, but lineary does not
    def run(self, iterator, play_context, result=0):
        self.track_mem(msg='before run')
        res = super(StrategyModule, self).run(iterator, play_context)
        self.track_mem(msg='after run')

        show_common_ansible_types()

        # example of dumping graphviz dot/pngs for ref graph of some objs
        #tis = objgraph.by_type('ansible.playbook.task_include.TaskInclude')
        #show_refs(filename='task_include_refs', objs=tis, max_depth=6, max_objs=1)

        return res

    def add_tqm_variables(self, vars, play):
        self.track_mem(msg='before add_tqm_variables')
        res = super(StrategyModule, self).add_tqm_variables(vars, play)
        self.track_mem(msg='after tqm_variables')
        return res

    def _queue_task(self, host, task, task_vars, play_context):
        self.track_mem(msg='before queue_task')
        res = super(StrategyModule, self)._queue_task(host, task, task_vars, play_context)
        self.track_mem(msg='after queue_task')
        return res

    def _load_included_file(self, included_file, iterator, is_handler=False):
        self.track_mem(msg='before _load_included_file')
        res = super(StrategyModule, self)._load_included_file(included_file, iterator, is_handler=is_handler)
        self.track_mem(msg='after _load_included_file')
        return res

    def _process_pending_results(self, iterator, one_pass=False, max_passes=None):
        self.track_mem(msg='before _process_pending_results')
        res = super(StrategyModule, self)._process_pending_results(iterator, one_pass, max_passes)
        self.track_mem(msg='after _process_pending_results')
        return res
EOF
