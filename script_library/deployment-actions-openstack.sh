#!/bin/bash

# Ensure variables are always set before going forward.
# Will prevent this script to be runned unless called from run.sh (by design)
set -o nounset

set -o errexit

echo "Deploying on OpenStack"

source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_env_vars_set

function deploy_ses(){
    source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_environment_is_ready_for_deploy
    echo "Starting a SES deploy"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-ses_aio.yml
    echo "ses-ansible deploy is successful"
}
function deploy_caasp(){
    source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_environment_is_ready_for_deploy
    echo "Starting caasp deploy"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-caasp.yml
    echo "CaaSP deployed successfully"
}
function deploy_ccp_deployer() {
    source ${scripts_absolute_dir}/pre-flight-checks.sh check_openstack_environment_is_ready_for_deploy
    echo "Creating CCP deploy node"
    run_ansible ${socok8s_absolute_dir}/openstack-osh.yml
}
function enroll_caasp_workers() {
    echo "Enrolling caasp worker nodes into the cluster"
    run_ansible ${socok8s_absolute_dir}/playbooks/caasp-enroll_nodes_in_cluster.yml
    echo "Ensure CaaSP workers are ready for OSH"
    run_ansible -i inventory-osh.ini -t workersetup ${socok8s_absolute_dir}/7_deploy_osh/play.yml
}
function patch_upstream(){
    echo "Running dev-patcher"
    echo "Nothing will happen if developer mode is not set"
    echo "TODO: Separate this into a different playbook"
    run_ansible -i inventory-osh.ini -t upstream_patching ${socok8s_absolute_dir}/7_deploy_osh/play.yml
}
function build_images(){
    echo "Running image builder"
    echo "Nothing will happen if developer mode is not set"
    echo "TODO: Separate this into a different playbook"
    run_ansible -i inventory-osh.ini -e "build_osh_images=yes" ${socok8s_absolute_dir}/7_deploy_osh/play.yml
}
function deploy_osh(){
    echo "Now deploy SUSE version of OSH"
    run_ansible ${socok8s_absolute_dir}/playbooks/generic-deploy_osh.yml
}
function teardown(){
    clean_openstack
    clean_userfiles
}
function clean_k8s(){
    echo "DANGER ZONE. Set the env var 'DELETE_ANYWAY' to 'YES' to delete everything in your userspace."
    if [[ ${DELETE_ANYWAY:-"NO"} == "YES" ]]; then
        echo "DELETE_ANYWAY is set, cleaning up k8s"
        ansible -m script -a "script_library/cleanup-k8s.sh" osh-deployer -i inventory-osh.ini
    fi
}
function clean_openstack(){
    echo "Deleting on OpenStack"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-osh_instance.yml -e osh_node_delete=True || true
    echo "Delete Caasp nodes"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-caasp.yml -e caasp_stack_delete=True || true
    echo "Delete SES node"
    run_ansible ${socok8s_absolute_dir}/playbooks/openstack-ses_aio_instance.yml -e ses_node_delete=True
}
function clean_userfiles(){
    echo "DANGER ZONE. Set the env var 'DELETE_ANYWAY' to 'YES' to delete everything in your userspace."
    if [[ ${DELETE_ANYWAY:-"NO"} == "YES" ]]; then
        echo "DELETE_ANYWAY is set, deleting user files"
        rm -rf ~/suse-osh-deploy/
    fi
}
