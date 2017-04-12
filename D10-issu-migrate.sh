source contrail-issu.conf

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

# Step 1
# add new control nodes to old CFGM
echo "== Step 1 =="
for i in "${!control_new_dict[@]}"
do
  cmd="ssh root@${old_control_arr[0]} python /opt/contrail/utils/provision_control.py --hostname ${control_new_dict[$i]} --host_ip $i api_server_ip ${old_control_arr[0]} --api_server_port 8082 --oper add --admin_user admin --admin_password $admin_password admin_tenant_name admin --router_asn 64512"
  echo "$cmd"
done

# Step 2
# add old control nodes to new CFGM
echo "== Step 2 =="
for i in "${!control_old_dict[@]}"
do
  cmd="ssh root@${new_control_arr[0]} python /opt/contrail/utils/provision_control.py --hostname ${control_old_dict[$i]} --host_ip $i api_server_ip ${new_control_arr[0]} --api_server_port 8082 --oper add --admin_user admin --admin_password $admin_password admin_tenant_name admin --router_asn 64512"
  echo "$cmd"
done

# Step 3
# Disable all but contrail-api, discovery and ifmap on new cluster CFGM
echo "== Step 3 == Quotes need to be changed in the command"
for i in "${!config_new_dict[@]}"
do
  cmd="ssh root@$i openstack-config --set /etc/contrail/supervisord_config.conf include files '/etc/contrail/supervisord_config_files/contrail-api.ini  /etc/contrail/supervisord_config_files/contrail-discovery.ini /etc/contrail/supervisord_config_files/ifmap.ini' && service supervisor-config stop"
  echo $cmd
done 

# Step 4
# Perform ISSU pre sync
echo "== Step 4 =="
cmd="root@${new_control_arr[0]} contrail-issu-pre-sync -c /etc/contrail/contrail-issu.conf"
echo $cmd

# Step 5
# Add issu-run-sync to supervisor and start issu-run-sync
echo "== Step 4 =="
function issu_run_sync {
    local cmd='openstack-config --set /etc/supervisord.d/contrail-issu.conf program:contrail-issu'
    touch /etc/supervisord.d/contrail-issu.conf
    $cmd command 'contrail-issu-run-sync --conf_file /etc/contrail/contrail-issu.conf'
    $cmd numprocs 1
    openstack-config --set /etc/supervisord.d/contrail-issu.conf program:contrail-issu process_name '%(process_num)s'
    $cmd redirect_stderr true
    openstack-config --set /etc/supervisord.d/contrail-issu.conf program:contrail-issu stdout_logfile  '/var/log/issu-contrail-run-sync-%(process_num)s-stdout.log'
    openstack-config --set /etc/supervisord.d/contrail-issu.conf program:contrail-issu stderr_logfile '/dev/null'
    $cmd priority 440
    $cmd autostart true
    $cmd killasgroup false
    $cmd stopsignal KILL
    $cmd exitcodes 0
    service supervisor restart
}
