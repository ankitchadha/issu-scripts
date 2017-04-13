#!/usr/bin/env bash
source /etc/contrail/contrail-issu.conf

# Step 0
# creating dictionary for config and control
control_host_info_trimmed=$(echo $control_host_info | cut -d "{" -f2 | cut -d "}" -f1)
declare -A control_new_dict
for i in $(echo $control_host_info_trimmed | sed "s/,/ /g")
do
currentIP="nil"
for j in $(echo $i| sed "s/:/ /g")
do
if [ "$currentIP" = "nil" ] ; then
	currentIP=$j
else
	control_new_dict[$currentIP]=$j
fi
done
done

config_host_info_trimmed=$(echo $config_host_info | cut -d "{" -f2 | cut -d "}" -f1)
declare -A config_new_dict
for i in $(echo $config_host_info_trimmed | sed "s/,/ /g")
do
currentIP="nil"
for j in $(echo $i| sed "s/:/ /g")
do
if [ "$currentIP" = "nil" ] ; then
	currentIP=$j
else
	config_new_dict[$currentIP]=$j
fi
done
done

old_control_host_info_trimmed=$(echo $old_control_host_info | cut -d "{" -f2 | cut -d "}" -f1)
declare -A control_old_dict
for i in $(echo $old_control_host_info_trimmed | sed "s/,/ /g")
do
currentIP="nil"
for j in $(echo $i| sed "s/:/ /g")
do
if [ "$currentIP" = "nil" ] ; then
        currentIP=$j
else
        control_old_dict[$currentIP]=$j
fi
done
done

old_control_arr=()
for i in $(echo $old_control_list | sed "s/,/ /g")
do
old_control_arr+=($i)
done

new_control_arr=()
for i in $(echo $new_control_list | sed "s/,/ /g")
do
new_control_arr+=($i)
done

function issu_contrail_prepare_compute_node {
    echo "== Step 1 =="
    # Remove vrouter files from supervisord
    ssh root@$1 sudo route -n && sudo openstack-config --del /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent autostart
    ssh root@$1 sudo openstack-config --del /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent killasgroup
    ssh root@$1 contrail-status
}

function issu_contrail_upgrade_compute_node {
	echo "== Step 2 =="
	# Create new repo, upgrade contrail-openstack-vrouter (or upgrade these: contrail-vrouter-common, openstack-util
	# Need to use: upgrade-vnc-compute configure_nova=no manage_nova_compute=no -P contrail-vrouter-common, openstack-util -F <from release> -T <target release>
	ssh root@$1 sudo yum upgrade -y contrail-vrouter-common openstack-utils
}

function issu_contrail_switch_compute_node {
    echo "== Step 3=="
    # Restore the supervisor-vrouter settings and point to new discovery IP
    ssh root@$1 sudo route -n
    ssh root@$1 sudo openstack-config --set /etc/contrail/contrail-vrouter-agent.conf DISCOVERY server ${new_control_arr[0]}
    ssh root@$1 sudo openstack-config --set /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent autostart true
    ssh root@$1 sudo openstack-config --set /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent killasgroup true
    ssh root@$1 sudo openstack-config --set /etc/contrail/contrail-vrouter-nodemgr.conf DISCOVERY server %s ${new_control_arr[0]}
    ssh root@$1 sudo service supervisor-vrouter restart
    ssh root@$1 sudo contrail-status
    ssh root@$1 sudo route -n
}


	 


## Call functions in this order
issu_contrail_prepare_compute_node
#issu_contrail_prepare_compute_node
#issu_contrail_switch_compute_node
