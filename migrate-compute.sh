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
    for i in "$@"
    do
      ssh root@$i sudo route -n
      ssh root@$i  sudo openstack-config --del /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent autostart
      ssh root@$i sudo openstack-config --del /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent killasgroup
      ssh root@$i contrail-status
    done
}

function issu_contrail_upgrade_compute_node {
    echo "== Step 2 =="
    # Create new repo, upgrade contrail-openstack-vrouter (or upgrade these: contrail-vrouter-common, openstack-util
    # Need to use: upgrade-vnc-compute configure_nova=no manage_nova_compute=no -P contrail-vrouter-common, openstack-util -F <from release> -T <target release>
    for i in "$@"
    do
      ssh root@$1 sudo yum upgrade -y contrail-vrouter-common openstack-utils
    done
}

function issu_contrail_switch_compute_node {
    echo "== Step 3=="
    # Restore the supervisor-vrouter settings and point to new discovery IP
    for i in "$@"
    do
      ssh root@$i sudo route -n
      ssh root@$i sudo openstack-config --set /etc/contrail/contrail-vrouter-agent.conf DISCOVERY server ${new_control_arr[0]}
      ssh root@$i sudo openstack-config --set /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent autostart true
      ssh root@$i sudo openstack-config --set /etc/contrail/supervisord_vrouter_files/contrail-vrouter-agent.ini program:contrail-vrouter-agent killasgroup true
      ssh root@$i sudo openstack-config --set /etc/contrail/contrail-vrouter-nodemgr.conf DISCOVERY server %s ${new_control_arr[0]}
      ssh root@$i sudo service supervisor-vrouter restart
      ssh root@$i sudo contrail-status
      ssh root@$i sudo route -n
    done
}


## Call functions in this order
#issu_contrail_prepare_compute_node $@
#issu_contrail_upgrade_compute_node $@
#issu_contrail_switch_compute_node $@
