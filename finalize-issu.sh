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

function issu_contrail_stop_old_node {
    # Stop services on the old cluster
    echo "== Step 1=="
    for i in "${!control_old_dict[@]}"
    do
      ssh root@{config_old_dict[$i]} sudo service supervisor-config stop && sudo service supervisor-control stop && sudo service supervisor-webui stop
    done
    for i in "${!analytics_old_dict[@]}"
    do
      ssh root@{analytics_old_dict[$i] sudo service supervisor-collector stop
    done
}

function issu_post_sync {
    rm -f /etc/supervisord.d/contrail-issu.ini
    service supervisor restart
    contrail-issu-post-sync -c /etc/contrail/contrail-issu.conf
    contrail-issu-zk-sync -c /etc/contrail/contrail-issu.conf
}

function issu_contrail_post_new_control {
    for i in "${!control_new_dict[@]}"
    do
      ssh root@$i contrail-status
      ssh root@$i issu_contrail_set_supervisord_config_files 'contrail-device-manager' 'true'
      ssh root@$i issu_contrail_set_supervisord_config_files 'contrail-svc-monitor' 'true'
      ssh root@$i issu_contrail_set_supervisord_config_files 'contrail-schema' 'true'
      ssh root@$i openstack-config --del /etc/contrail/supervisord_config_files/contrail-config-nodemgr.ini eventlistener:contrail-config-nodemgr autorestart
      ssh root@$i openstack-config --del /etc/contrail/supervisord_config_files/contrail-config-nodemgr.ini eventlistener:contrail-config-nodemgr autostart
      ssh root@$i service supervisor-config restart
    done
}

function issu_contrail_migrate_nb {
    for i in $(echo $new_rabbit_address_list | sed "s/,/ /g")
    do
      ssh root@$i sed -i 
    #### TBD 
}
# Call functions in this order
#issu_contrail_stop_old_node
#issu_post_sync
#issu_contrail_post_new_control
#issu_contrail_migrate_nb oldip newip
#issu_contrail_finalize_config_node
