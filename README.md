# Zero Touch Provisioning - OCP at the Edge

The purpose of this repo is to have a track to show how it is possible to provision OCP Clusters (SNO/Compact 3-node/etc) at the edge, at scale.

What you need to have it working:

- An OCP cluster with Red Hat Advanced cluster management for Kubernetes and Openshift GitOps installed
- Enough resources to spin up a KVM VM for a Single Node OCP Cluster (8vCPU, 32G Memory, 100GB disk)
- Ansible
- 20-30 minutes of your time :)

## Setup

### Pre-requisites

In order to prepare the environment for provisioning, you need to install collections and roles that are required for the execution:

    ansible-galaxy collection install -r requirements.yml
    ansible-galaxy role install -r requirements.yml


### Sushy-tools

In order to emulate a Baseboard Management Controller (BMC) we will use sushy-emulator []() running as a privilegede container on our VM host. This will allow interacting with VMs as if they were Bare Metal servers.

To deploy the emulator, you can simply run the playbook:

    ansible-playbook -i inventory 00_deploy_bmc_emulator.yml

This will configure a listening service on port 8000 (default) on any interface (0.0.0.0). You can configure the port and interface by setting the **ztp_bmc_port** and **ztp_bmc_host** variables as well as BMC username/password using the **ztp_bmc_username** and **ztp_bmc_password** variables


### VMs and manifests generation

The second step will be the creation of the VMs, using terraform ([https://www.terraform.io/](https://www.terraform.io/)) on KVM.

Here are some of the configurations that can be provided, according to them the templates will be created, overrides to following settings must be passed using the **group_vars/vm_host** group variables file:

| *variable*                | *description*                                                 | *default*                                                                     |
|---------------------------|---------------------------------------------------------------|-------------------------------------------------------------------------------|
| ztp_working_directory:    | Where all cluster-related manifests and files will be stored  | ~                                                                             |
| ztp_cluster_name:         | Name of the SNO cluster                                       | ztp-sno                                                                       |
| ztp_cluster_domain:       | Domain of the SNO cluster                                     |ocpdemo.labs                                                                   |
| ztp_network_cidr:         | CIDR of the cluster                                           |192.168.235.0/24                                                               |
| ztp_node_name:            | Hostname of the node                                          |ztp-sno                                                                        |
| ztp_node_ip:              | IP of the Node                                                |192.168.235.2                                                                  |
| ztp_node_cpu:             | Number of vCPUs for the cluster                               |8                                                                              |
| ztp_node_memory:          | Memory capacity for the node                                  |32                                                                             |
| ztp_bmc_host:             | IP of the interface to bind for sushy-tools                   |0.0.0.0                                                                        |
| ztp_bmc_port:             | Port to bind for sushy-tools                                  |32                                                                             |
| ztp_bmc_username:         | BMC username if set                                           |admin                                                                          |
| ztp_bmc_password:         | BMC Password if set                                           |admin                                                                          |
| ztp_pull_secret:          | Pull secret                                                   |no default                                                                     |
| git_branch                | The branch to clone from/to push to                           | main                                                                          |
| git_repo_url              | The HTTPS URL of the repository                               | no default                                                                    |
| git_repo_email            | The email of the user (only for push action)                  | no default                                                                    |
| git_repo_token            | The GitHub token to use for pushing/cloning repos             | no default - Leave it empty or undefined to use SSH keys                      |
| git_repo_username         | The GitHub username to use when interacting with the repo     | no default                                                                    |
| git_working_dir           | The directory where the the repo should be cloned (clone action), or the folder that contains the cloned repository folder (push action) | ~  |

To create the VMs and generate the manifests:

    ansible-playbook -i inventory 01_ztp_vm_creation.yml

### Update the GitOps repository with the new cluster

Optionally, you can specify some additional GitHub parameters to allow the playbook to create a new folder with the cluster name and push it to your repository, generating the ArgoCD application that you can go and apply into Red Hat Openshift Container Platform.

    ansible-playbook -i inventory 02_publish_gitops_manifests.yml

The **git_** variables are needed to interact with the git repository, to use SSH keys, just leave the *git_repo_token* variable empty.

### Deploy Cluster resources

Once manifests are generated and pushed, you can simply create an application in Openshift GitOps, below you can find a sample.

    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
    name: <yourappname>
    namespace: openshift-gitops
    spec:
    destination:
        server: https://kubernetes.default.svc
        namespace: <yourclustername>
    source:
        path: <yourclustername>
        repoURL: <yourrepo>
        targetRevision: <yourbranch>
    syncPolicy:
        automated:
        prune: true
        selfHeal: true
        syncOptions:
        - CreateNamespace=true
