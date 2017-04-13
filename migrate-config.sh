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

function add_new_to_old {
    # add new control nodes to old CFGM
    echo "== Step 1 =="
    for i in "${!control_new_dict[@]}"
    do
      ssh root@${old_control_arr[0]} python /opt/contrail/utils/provision_control.py --host_name ${control_new_dict[$i]} --host_ip $i --api_server_ip ${old_control_arr[0]} --api_server_port 8082 --oper add --admin_user admin --admin_password $admin_password --admin_tenant_name admin --router_asn 64512
      #echo $cmd
    done
}

function add_old_to_new {    
    # add old control nodes to new CFGM
    echo "== Step 2 =="
    for i in "${!control_old_dict[@]}"
    do
      ssh root@${new_control_arr[0]} python /opt/contrail/utils/provision_control.py --host_name ${control_old_dict[$i]} --host_ip $i --api_server_ip ${new_control_arr[0]} --api_server_port 8082 --oper add --admin_user admin --admin_password $admin_password --admin_tenant_name admin --router_asn 64512
      #echo "$cmd"
    done
}

function disable_services_on_new {    
    # Disable all but contrail-api, discovery and ifmap on new cluster CFGM
    echo "== Step 3 =="
    for i in "${!config_new_dict[@]}"
    do
      ssh root@$i openstack-config --set /etc/contrail/supervisord_config.conf include files "/etc/contrail/supervisord_config_files/contrail-api.ini /etc/contrail/supervisord_config_files/contrail-discovery.ini /etc/contrail/supervisord_config_files/ifmap.ini" && service supervisor-config stop
    done
}

function freeze_nb {
    # Freeze all NB APIs on OS node
    echo "== Step 4 =="
    ssh root@$openstack_ip service haproxy stop
}

function issu_pre_sync {    
    # Perform ISSU pre sync
    echo "== Step 5 =="
    ssh root@${new_control_arr[0]} contrail-issu-pre-sync -c /etc/contrail/contrail-issu.conf
    #echo $cmd
}

function issu_run_sync {
    # Add issu-run-sync to supervisor and start issu-run-sync
    echo "== Step 6 =="
    local cmd='openstack-config --set /etc/supervisord.d/contrail-issu.ini program:contrail-issu'
    touch /etc/supervisord.d/contrail-issu.ini
    $cmd command 'contrail-issu-run-sync --conf_file /etc/contrail/contrail-issu.conf'
    $cmd numprocs 1
    openstack-config --set /etc/supervisord.d/contrail-issu.ini program:contrail-issu process_name '%(process_num)s'
    $cmd redirect_stderr true
    openstack-config --set /etc/supervisord.d/contrail-issu.ini program:contrail-issu stdout_logfile  '/var/log/issu-contrail-run-sync-%(process_num)s-stdout.log'
    openstack-config --set /etc/supervisord.d/contrail-issu.ini program:contrail-issu stderr_logfile '/dev/null'
    $cmd priority 440
    $cmd autostart true
    $cmd killasgroup false
    $cmd stopsignal KILL
    $cmd exitcodes 0
    service supervisord restart
}


# Call functions in this order
add_new_to_old
add_old_to_new
freeze_nb
disable_services_on_new
issu_pre_sync
issu_run_sync
