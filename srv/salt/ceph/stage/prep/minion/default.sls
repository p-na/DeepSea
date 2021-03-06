sync:
  salt.state:
    - tgt: '*'
    - sls: ceph.sync

repo:
  salt.state:
    - tgt: '*'
    - sls: ceph.repo

common packages:
  salt.state:
    - tgt: '*'
    - sls: ceph.packages.common

mines:
  salt.state:
    - tgt: '*'
    - sls: ceph.mines

{% if salt['saltutil.runner']('cephprocesses.mon') == True %}

#warning_before:
#  salt.state:
#    - tgt: {{ salt['pillar.get']('master_minion') }}
#    - sls: ceph.warning.noout
#    - failhard: True

{% for host in salt.saltutil.runner('orderednodes.unique', cluster='ceph') %}

starting {{ host }}:
  salt.runner:
    - name: minions.message
    - content: "Processing host {{ host }}"

wait until the cluster has recovered before processing {{ host }}:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.wait
    - failhard: True

check if all processes are still running after processing {{ host }}:
  salt.state:
    - tgt: '*'
    - sls: ceph.processes
    - failhard: True

unset noout {{ host }}:
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

updating {{ host }}:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates
    - failhard: True

set noout {{ host }}:
  salt.state:
    - sls: ceph.noout.set
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

restart {{ host }} if updates require:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates.restart
    - failhard: True

finished {{ host }}:
  salt.runner:
    - name: minions.message
    - content: "Finished host {{ host }}"

{% endfor %}

unset noout after final iteration: 
  salt.state:
    - sls: ceph.noout.unset
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - failhard: True

starting remaining minions:
  salt.runner:
    - name: minions.message
    - content: "Processing minions without roles"

updating minions without roles:
  salt.state:
    - tgt: I@cluster:ceph
    - tgt_type: compound
    - sls: ceph.updates
    - failhard: True

restarting minions without roles:
  salt.state:
    - tgt: I@cluster:ceph
    - tgt_type: compound
    - sls: ceph.updates.restart
    - failhard: True

finishing remaining minions:
  salt.runner:
    - name: minions.message
    - content: "Finished minions without roles"

#warning_after:
#  salt.state:
#    - tgt: {{ salt['pillar.get']('master_minion') }}
#    - sls: ceph.warning.noout
#    - failhard: True

# Here needs to be 100% definitive check that the cluster is not up yet.
# the parent if conditional can be False if one of the mons is down.
# but even if all are down, this is no indication of rebooting/updateing
# all nodes at once
{% else %}

updates:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates


restart:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates.restart

{% endif %}
