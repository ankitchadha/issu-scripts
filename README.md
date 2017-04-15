# issu-scripts
bash scripts for executing Contrail-ISSU on a RedHat Director provisioned system.


-- follow usual steps:

0. Get THT, contrail-tripleo-puppet and puppet-contrail from github
TripleO Heat Templates: https://github.com/ankitchadha/contrail-tripleo-heat-templates.git -b upgrade-test
contrail-tripleo-puppet: https://github.com/ankitchadha/contrail-tripleo-heat-templates.git -b upgrade-test
puppet-contrail: https://github.com/ankitchadha/puppet-contrail.git -b stable/newton
1. Set count for contrail*container = 0
2. deploy overcloud (this will be the initial overcloud that gets deployed). 
2.0. Usual instructions of deploying overcloud still apply
2.1. Create nova instances. Or any other objects
3. host new repo on undercloud
4. set new repo's location in contrail-services (ContrailRepoNew = http://192.0.2.1/<location>). 
4.1. Modify firstboot according to the location of the new repo
5. Create new RMQ vhost on OS node(s). 
5.0. This can be done as part of migrate_config as well. But it's better to perform this task before proceeding to ISSU tasks.
rabbitmqctl add_vhost /new
rabbitmqctl set_permissions -p /new guest ".*" ".*" ".*"
6. set the count for contrail*container (3 for HA, 1 for non-HA)
7. Update heat stack
8. New cluster should come up parallel to the existing one
8.1. Nova instances created in 2.1. should still work

9. Get contrail-issu wrapper scripts:
https://github.com/ankitchadha/issu-scripts.git

10. Start ISSU
10.1. ./migrate_config
10.2. ./migrate_compute <IP of compute> #Do not use the int-api network IP here
10.3. ./finalize_issu


Pre-Req's for ISSU:
-- Get contrail-issu scripts from github
-- contrail-issu scripts would be run from one of the new contrail-controller nodes. Set up passwordless SSH from this node to all other overcloud nodes
	-- Will automate this in later version of the repo
-- add repo_location in contrail-issu.conf (this file is copied from new controller to computes)
repo_location=/etc/yum.repos.d/contrail-new.repo
