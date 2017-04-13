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


# Call functions in this order
add_new_to_old
add_old_to_new
freeze_nb
disable_services_on_new
issu_pre_sync
issu_run_sync
