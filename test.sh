#!/usr/bin/env bash
source /etc/contrail/contrail-issu.conf

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

old_control_arr=()
for i in $(echo $old_control_list | sed "s/,/ /g")
do
old_control_arr+=($i)
done

echo "== Step 1 =="
for i in "${!control_new_dict[@]}"
do
  #ssh root@${old_control_arr[0]} ip addr sh | grep 10.0.0
  ssh root@${old_control_arr[0]} python /opt/contrail/utils/provision_control.py --hostname ${control_new_dict[$i]} --host_ip $i api_server_ip ${old_control_arr[0]} --api_server_port 8082 --oper add --admin_user admin --admin_password $admin_password admin_tenant_name admin --router_asn 64512
  #echo "$cmd"
done
