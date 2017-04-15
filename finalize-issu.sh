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
      ssh root@{config_old_dict[$i]} sudo service supervisor-config stop;sudo service supervisor-control stop;sudo service supervisor-webui stop
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
      ssh root@$i hostname
      ssh root@$i contrail-status
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-device-manager.ini program:contrail-device-manager autostart true
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-device-manager.ini program:contrail-device-manager autorestart true  
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-device-manager.ini program:contrail-device-manager killasgroup true
      
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-svc-monitor.ini program:contrail-svc-monitor autostart true 
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-svc-monitor.ini program:contrail-svc-monitor autorestart true
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-svc-monitor.ini program:contrail-svc-monitor killasgroup true
      
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-schema.ini program:contrail-schema autostart true
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-schema.ini program:contrail-schema autorestart true
      openstack-config --set /etc/contrail/supervisord_config_files/contrail-schema.ini program:contrail-schema killasgroup true

      ssh root@$i openstack-config --del /etc/contrail/supervisord_config_files/contrail-config-nodemgr.ini eventlistener:contrail-config-nodemgr autorestart
      ssh root@$i openstack-config --del /etc/contrail/supervisord_config_files/contrail-config-nodemgr.ini eventlistener:contrail-config-nodemgr autostart
      ssh root@$i service supervisor-config restart
    done
}

function issu_contrail_migrate_nb {
    for i in $(echo $new_rabbit_address_list | sed "s/,/ /g")
    do
      num=0
      for j in $(echo $old_control_list | sed "s/,/ /g")
      do
        ssh root@$i sed -i -e \"s/${old_control_arr[$num]}/${new_control_arr[$num]}/g\" /etc/haproxy/haproxy.cfg
        echo ${old_control_arr[$num]}
        echo ${new_control_arr[$num]}
        num+=1
      done
      ssh root@$i service haproxy restart
      ssh root@$i hostname
    done
    #### TBD 
}

function issu_contrail_finalize_config_node {
    sudo python /opt/contrail/utils/provision_issu.py -c /etc/contrail/contrail-issu.conf
}
# Call functions in this order

#issu_contrail_stop_old_node
#issu_post_sync
#issu_contrail_post_new_control
#issu_contrail_migrate_nb 
#issu_contrail_finalize_config_node
