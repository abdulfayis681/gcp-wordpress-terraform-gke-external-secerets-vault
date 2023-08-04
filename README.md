
# Manage Credentials and other sensitive data from kubernetes

- Deploy an mysql wordpress in GKE cluster
- Manage secrets in external secrets service integrated with vault 


here, we are deployed a gcloud mysql based wordpress with loadbalancer and integrated secrets with vault and external secrets



### list of services were used 

- GKE Cluster 
- Cloud SQL 
- External Secrets 
- hashicorp Vault

### Prerequisites
Before using this module, you should have the following:

  - An GCP account  necessary permissions to manage resources
  - Terraform installed on your local machine
  - gcloud cli configured 
  - kubectl configured
  - helm installed on machine 

## procedure
  
### Deploy an GKE cluster with Terraform

##### Configure Terraform GCS Backend

When you create resources in GCP such as VPC, Terraform needs a way to keep track of
them. If you simply apply terraform right now, it will keep all the state locally on your
computer.


    terraform {
    backend "gcs" {
    bucket = "Bucketname"
    prefix = "terraform/state"
    }
    required_providers {
    google = {
    source
    = "hashicorp/google"
    version = "~> 4.0"
    }
    }
    }
Provider.tf 





➔ Don’t forgot to create GKE bucket and edit the bucket name in
provider.tf file.

##### Create VPC in GCP using Terraform

    resource "google_project_service" "compute" {
     project            = var.projectid
     service            = "compute.googleapis.com"
     disable_on_destroy = false
    }
    
    resource "google_project_service" "container" {
     project            = var.projectid
     service            = "container.googleapis.com"
     disable_on_destroy = false
    }
    
    resource "google_compute_network" "main" {
     name                            = "${var.clustername}-main"
     routing_mode                    = "REGIONAL"
     auto_create_subnetworks         = false
     mtu                             = 1460
     delete_default_routes_on_create = false
     project                         = var.projectid
    
     depends_on = [
       google_project_service.compute,
       google_project_service.container
     ]
    }
Vpc.tf

##### Create Subnet in GCP using Terraform

    resource "google_compute_subnetwork" "private" {
     name                     = "${var.clustername}-private"
     ip_cidr_range            = "10.0.0.0/18"
     region                   = var.region
     network                  = google_compute_network.main.self_link
     private_ip_google_access = true
     project                  = var.projectid
    
     secondary_ip_range {
       range_name    = "k8s-pod-range"
       ip_cidr_range = "10.48.0.0/14"
     }
     secondary_ip_range {
       range_name    = "k8s-service-range"
       ip_cidr_range = "10.52.0.0/20"
     }
    }

Subnets.tf 

##### Create Cloud Router in GCP using Terraform

    resource "google_compute_router" "router" {
     name    = "${var.clustername}-router"
     region  = var.region
     network = google_compute_network.main.id
     project = var.projectid
    }
    
Router.tf

##### Create Cloud NAT in GCP using Terraform



    resource "google_compute_router_nat" "nat" {
     name    = "${var.clustername}-nat"
     project = var.projectid
     router  = google_compute_router.router.name
     region  = var.region
    
     source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
     nat_ip_allocate_option             = "MANUAL_ONLY"
    
     subnetwork {
       name                    = google_compute_subnetwork.private.id
       source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
     }
    
     nat_ips = [google_compute_address.nat.self_link]
    }
    
    
    resource "google_compute_address" "nat" {
     name         = "${var.clustername}-nat"
     address_type = "EXTERNAL"
     network_tier = "PREMIUM"
     project      = var.projectid
     region       = var.region
    
     depends_on = [google_project_service.compute]
    }

Nat.tf
##### Create Firewall in GCP using Terraform

    resource "google_compute_firewall" "allow-ssh" {
     name    = "${var.clustername}-allow-ssh"
     project = var.projectid
     network = google_compute_network.main.name
    
     allow {
       protocol = "tcp"
       ports    = ["22"]
     }
    
     source_ranges = ["0.0.0.0/0"]
    }

firewall.tf
##### Create GKE Cluster Using Terraform

    resource "google_container_cluster" "primary" {
     name                     = var.clustername
     project                  = var.projectid
     location                 = "${var.region}-a"
     remove_default_node_pool = true
     initial_node_count       = 1
     network                  = google_compute_network.main.self_link
     subnetwork               = google_compute_subnetwork.private.self_link
     logging_service          = "logging.googleapis.com/kubernetes"
     monitoring_service       = "monitoring.googleapis.com/kubernetes"
     networking_mode          = "VPC_NATIVE"
    
    
    
     addons_config {
       http_load_balancing {
         disabled = true
       }
       horizontal_pod_autoscaling {
         disabled = false
       }
     }
    
     release_channel {
       channel = "REGULAR"
     }
    
     workload_identity_config {
       workload_pool = "${var.projectid}.svc.id.goog"
     }
    
     ip_allocation_policy {
       cluster_secondary_range_name  = "k8s-pod-range"
       services_secondary_range_name = "k8s-service-range"
    
     }
    
    
     private_cluster_config {
       enable_private_nodes    = true
       enable_private_endpoint = false
       master_ipv4_cidr_block  = "172.16.0.0/28"
     }
    
     node_config {
       workload_metadata_config {
         mode = "GKE_METADATA"
       }
     }
    
    }

Kubernetes.tf 

##### Create GKE Node Pools using Terraform
    resource "google_service_account" "kubernetes" {
     account_id = "your-account-id"
     project    = var.projectid
    }
    
    
    resource "google_container_node_pool" "general" {
     name       = "${var.clustername}-general"
     cluster    = google_container_cluster.primary.id
     node_count = var.nodecount
    
     management {
       auto_repair  = true
       auto_upgrade = true
     }
    
     node_config {
       preemptible  = false
       machine_type = var.machinetype
       image_type   = var.imagetype
       disk_size_gb = var.disksize
       disk_type    = var.disktype
       workload_metadata_config {
         mode = "GKE_METADATA"
       }
    
    
       labels = {
         role = "general"
       }
    
       service_account = google_service_account.kubernetes.email
       oauth_scopes = [
         "https://www.googleapis.com/auth/cloud-platform"
       ]
     }
    }

Node.tf

##### Terraform Variables
    Define Terraform variables for GKE resources:
    
    variable "projectid" {
     description = "The ID of the project"
     type        = string
    }
    
    variable "clustername" {
     description = "The name of the GKE cluster"
     type        = string
    }
    
    variable "region" {
     description = "The region for the GKE cluster"
     type        = string
    }
    
    variable "nodecount" {
     description = "The number of nodes in the GKE cluster"
     type        = number
    }
    
    variable "machinetype" {
     description = "The machine type for the GKE nodes"
     type        = string
    }
    
    variable "imagetype" {
     description = "The image type for the GKE nodes"
     type        = string
    }
    
    variable "disksize" {
     description = "The disk size in GB for the GKE nodes"
     type        = number
    }
    
    variable "disktype" {
     description = "The disk type for the GKE nodes"



Variables.tf

##### Set Terraform variables values as per your requirements:

    projectid       = "wordpress-393506"
    
    clustername     =  "gke-project"
    
    region          = "us-central1"
    
    nodecount       = 2
    
    machinetype     = "e2-standard-2"
    
    imagetype       = "COS_CONTAINERD"
    
    disksize        = 30
    
    disktype        = "pd-balanced"
    
Terraform.tfvars

##### Define Terraform output that required to connect with GKE cluster :

    output "project_id" {
     value       = var.projectid
     description = "The ID of the project"
    
    
    }
    
    output "cluster_name" {
     value       = var.clustername
     description = "The name of the GKE cluster"
    }
    
    output "region" {
     value       = var.region
     description = "The region for the GKE cluster"
    }
    
    output "node_count" {
     value       = var.nodecount
     description = "The number of nodes in the GKE cluster"
    }
    
    output "machine_type" {
     value       = var.machinetype
     description = "The machine type for the GKE nodes"
    }
    
    output "image_type" {
     value       = var.imagetype
     description = "The image type for the GKE nodes"
    }
    
    output "disk_size" {
     value       = var.disksize
     description = "The disk size in GB for the GKE nodes"
    }
    
    output "disk_type" {
     value       = var.disktype
     description = "The disk type for the GKE nodes"
    }
    
    output "command_line_access" {
     value       = "gcloud container clusters get-credentials ${var.clustername} --zone ${var.region}-a --project ${var.projectid}"
     description = "Configure kubectl command line access by running the following command"
    }

Output.tf

##### Terraform Execution: Infrastructure Resources Provisioning

Once you have finished declaring the resources, you can deploy all resources.

- terraform init: command is used to initialize a working directory containing Terraform configuration files.

- terraform plan: command creates an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure.

- terraform apply: command executes the actions proposed in a Terraform plan to create or update infrastructure.


connect cluster using command 
  
    gcloud container clusters get-credentials "$cluster_name" --region "$cluster_region"

#### Install Hashicorp Vault in Kubernetes

let’s add the helm chart repository for Vault:

###### important: check or install helm 

    helm repo add hashicorp https://helm.releases.hashicorp.com

Command to install Vault
Next, we issue the command to install Vault, using the helm command with a couple of parameters:

    helm install vault hashicorp/vault --set='ui.enabled=true' --set='ui.serviceType=LoadBalancer'

###### Checking the Vault pods
We can now look at the containers and see if they are running in the Kubernetes cluster using the command. This will show the Vault pod and containers running therein.

    kubectl get pods 

###### Getting Pod Metadata
You can look at the pod metadata with this command:

    kubectl exec vault-0 env| grep vault
###### Vault operator init

The next step, now that we have the containers running is the vault operator init process where we initialize our vault server to setup vault after running the Vault helm chart. To run Vault on Kubernetes and initialize the Vault Server, we need to run the command below.

    kubectl exec --stdin=true --tty=true vault-0  -- vault operator init
This will preset you with unseal vault secrets which essentially provide the master key to unseal the vault. You will also see your initial root token for your production setup. Be sure to record the root token and the unseal keys securely

###### Vault unseal keys process

Next, we need to use the master keys to go through the unseal process, which has us paste in the unseal keys until the vault is unsealed.

##### Unseal the vault secrets
    kubectl exec --stdin=true --tty=true vault-0 -n vault -- vault operator unseal

###### Run this for the next three times and it will have you paste in the keys for Vault login.

#####Getting the load balancer IP address for connectivity to the Vault UI

Finally, we can take a look at our LoadBalancer IP address to see which external IP address is exposed to our Vault UI. I am using MetalLB in my lab, so here I see the external IP address assigned to the Vault pod.

##### Spinning Up a Vault Server

Since you now have vault installed, the next step is to spin up a vault server and create some secrets in it. This step is important as the vault server serves as the main component of all our vault operations (creating secrets, deleting secrets, etc)

Create a hcl file and paste in the following configuration settings, you can name this file what you want, this tutorial uses vault-config.hcl.




    cat <<EOF >> vault-config.hcl
    listener "tcp" {
    address = "0.0.0.0:8200"
    tls_disable = "true"
    }
    
    storage "raft" {
    path = "./vault/data"
    node_id = "node1"
    }
    cluster_addr = "http://127.0.0.1:8201"
    api_addr = "http://127.0.0.1:8200"
    EOF
    
.

 Explanations for the above configuration:

- `listener` - Configures how Vault is listening for API requests. It's currently set to listen on all interfaces so your Kubernetes Cluster can communicate to it.
- `storage` - Configures the storage backend where Vault data isstored. `Raft` is the integrated storage backend used by Vault.

    **Note:**
    When using the Integrated Storage backend, it is required to provide `cluster_addr` and `api_addr` to indicate the address and port to be used for communication between Vault servers in the cluster for client redirection.

3. Create the `vault` directory which will be used as storage from the current working directory:

    ```shell
    mkdir -p vault/data
    ```

4. Start the Vault server using the config file created in the above step:

    ```shell
    vault server -config=config.hcl
    ```

5. Open a new terminal instance and ssh into the droplet

6. Export the `VAULT_ADDR` environment variable to the following:

    ```shell
    export VAULT_ADDR=http://127.0.0.1:8200
    ```

7. Initialize the vault server with the following command:

    ```shell
    vault operator init
    ```

    ***IMPORTANT NOTE:***
    After the initialize command the ouput will show 5 `Unseal Keys` and an initial `Root Token`. These are very important. Vault is sealed by default so you will use three keys to unseal it. The `Root Token` value will be used in the `SecretStore` CRD to connect to the `Vault server` from the `Kubernetes Cluster`. You should save these values and keep them stored in a secure place like a Password Manager with limited access.

8. Export the `VAULT_TOKEN` environment variable to the value of the `Root Token` from the previous step:

    ```shell
    export VAULT_TOKEN=<ROOT_TOKEN_VALUE>

9. Unseal the vault server with the `Unseal Kyes` outputted above:

    ```shell
    vault operator unseal
    ```

    You should see something similar to the following:

    ```text
    root@vault:~# vault operator unseal
    Unseal Key (will be hidden):
    Key                Value
    ---                -----
    Seal Type          shamir
    Initialized        true
    Sealed             true
    Total Shares       5
    Threshold          3
    Unseal Progress    1/3
    Unseal Nonce       5f5492b4-b89a-cbf1-9e02-1f95c890710b
    Version            1.11.3
    Build Date         2022-08-26T10:27:10Z
    Storage Type       raft
    HA Enabled         true
    ```

    **Note:**
    Please note that you will need to repeat this step three times with different keys as shown in the `Unseal Progress` line.

10. Enable the KV secrets engine:

    ```shell
    vault secrets enable -path=secret/ kv
    ```

11. Check the status of the Vault server:

    ```shell
    vault status
    ```

    You should see something similar to the following:

    ```text
    root@vault:~# vault status
    Key                     Value
    ---                     -----
    Seal Type               shamir
    Initialized             true
    Sealed                  false
    Total Shares            5
    Threshold               3
    Version                 1.11.3
    Build Date              2022-08-26T10:27:10Z
    Storage Type            raft
    Cluster Name            vault-cluster-5641086a
    Cluster ID              9ea65968-d2fc-cca1-d396-75de70e1289b
    HA Enabled              true
    HA Cluster              https://127.0.0.1:8201
    HA Mode                 active
    Active Since            2022-09-09T12:21:20.509152959Z
    Raft Committed Index    36
    Raft Applied Index      36
    ```

    **Note:**
    Take note of the `Initialized` and `Sealed` lines. They should show `true` and `false`, respectively.

As a precaution you should also restrict incoming connections to the Vault Server Droplet to just the Kubernetes cluster. This is necessary as for the time being as TLS is disabled in the vault config file. To achieve this please follow the next steps:

1. Log into your DO account and go to the "Networking" --> "Firewalls" menu.
2. Click on the "Create Firewall" button.
3. Add a name to the firewall and from the Inbound rules configure the following rule: "Custom" rule type, "TCP" protocol, 8200 port and the "Source" should be set the Kubernetes Cluster which will consume secrets from the Vault server.
4. After the rule is created make sure you add this rule to the droplet from the "Droplets" menu.

**Note:**
TBD - Securing the Vault Server with TLS certificates.

At this point the Vault Server should be initialized and ready for use. In the next section you will create a `ClusterSecretStore` and `ExternalSecret` CRD.

##### Installing and Configuring the External Secrets Operator

In this step, you will learn how to deploy `External Secrets Operator` to your `DOKS` cluster, using `Helm`. The chart of interest can be found [here](https://github.com/external-secrets/external-secrets/).

First, clone the `Starter Kit` repository, and then change directory to your local copy:

```shell
git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

cd Kubernetes-Starter-Kit-Developers
```

Next, add the `External Secrets` Helm repository and list the available charts:

```shell
helm repo add external-secrets https://charts.external-secrets.io

helm repo update external-secrets

helm search repo external-secrets
```

The output looks similar to the following:

```text
NAME                                    CHART VERSION   APP VERSION     DESCRIPTION                              
external-secrets/external-secrets       0.5.9           v0.5.9          External secret management for Kubernetes
```

**Notes:**

- It's good practice in general, to use a specific version for the `Helm` chart. This way, you can `version` it using `Git`, and target if for a specific `release`. In this tutorial, the Helm chart version `0.5.9` is picked for `external-secrets`, which maps to application version `0.5.9`.

Next, install the stack using `Helm`. The following command installs version `0.5.9` of `external-secrets/external-secrets` in your cluster, and also creates the `external-secrets` namespace, if it doesn't exist (it also installs CRDs):

```shell
HELM_CHART_VERSION="0.5.9"

helm install external-secrets external-secrets/external-secrets --version "${HELM_CHART_VERSION}" \
  --namespace=external-secrets \
  --create-namespace \
  --set installCRDs=true
```

Finally, check `Helm` release status:

```shell
helm ls -n external-secrets
```

The output looks similar to (`STATUS` column should display 'deployed'):

```text
NAME                    NAMESPACE               REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
external-secrets        external-secrets        1               2022-09-10 10:33:50.324582 +0300 EEST   deployed        external-secrets-0.5.9  v0.5.9    
```

Next, inspect all the `Kubernetes` resources created for `External Secrets`:

```shell
kubectl get all -n external-secrets
```

The output looks similar to:

```text
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/external-secrets-66457766c4-95mvm                   1/1     Running   0          48s
pod/external-secrets-cert-controller-6bd49df95b-8bw6x   1/1     Running   0          48s
pod/external-secrets-webhook-579c46bf-g4z6p             1/1     Running   0          48s

NAME                               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/external-secrets-webhook   ClusterIP   10.245.78.48   <none>        443/TCP   49s

NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/external-secrets                   1/1     1            1           50s
deployment.apps/external-secrets-cert-controller   1/1     1            1           50s
deployment.apps/external-secrets-webhook           1/1     1            1           50s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/external-secrets-66457766c4                   1         1         1       50s
replicaset.apps/external-secrets-cert-controller-6bd49df95b   1         1         1       50s
replicaset.apps/external-secrets-webhook-579c46bf             1         1         1       50s
```

Next, you will create a `ClusterSecretStore`, which is what External Secrets Operator uses to store information about how to communicate with the given secrets provider. But before you work with the External Secrets Operator, you’ll need to add your Vault token inside a `Kubernetes secret` so that the External Secrets Operator can communicate with the secrets provider. This token was created when you first initalized the operator in [Step 2](#step-2---configuring-the-vault-server).

To create the Kubernetes secret containing the token follow the next steps:

```shell
kubectl create secret generic vault-token --from-literal=token=<YOUR_VAULT_TOKEN>
```

The output should look similar to:

```text
secret/vault-token created
```

**Note:**
The ClusterSecretStore is a cluster scoped SecretStore that can be referenced by all ExternalSecrets from all namespaces whereas SecretStore is namespaced. Use it to offer a central gateway to your secret backend.

A typical `ClusterSecretStore` configuration looks like below:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "<YOUR_DROPLET_ADDRESS>:<PORT>"
      path: "secret"
      version: "v1"
      auth:
        tokenSecretRef:
          name: "<YOUR_SECRET_NAME>"
          key: "<YOUR_SECRET_KEY>"
```

Explanations for the above configuration:

- `spec.provider.vault.server`: Interal IP address of the Vault server droplet. Runs on port 8200.
- `spec.provider.vault.path`: Path where secrets are located.
- `spec.provider.vault.version`: Version of the Vault KV engine.
- `auth.tokenSecretRef.name`: Name of the previously created secret holding the Root Token of the Vault server.
- `auth.tokenSecretRef.key`: Key name in the secret since the secret was created with a key-value pair.

Then, open and inspect the `06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). Please make sure to replace the `<>` placeholders accordingly:

```shell
code 06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml
```

Next, create the `ClusterSecretStore` resource:

```shell
kubectl apply -f 06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml
```

This command applies the `ClusterSecretStore` CRD to your cluster and creates the object. You can see the object by running the following command, which will show you all of the information about the object inside of Kubernetes:

```shell
kubectl get ClusterSecretStore vault-backend
```

You should see something similar to:

```text
NAME            AGE   STATUS   READY
vault-backend   97s   Valid    True
```

**Note:**
If you created the SecretStore successfully, you should see the `STATUS` column with a `Valid` value. If not, a very common issue is `message: unable to validate store`. This generally means that the authentication method for your client has failed as the ClusterSecretStore will try and create a client for your provider to verify everything is working. Recheck the secret containing the token and the status of the vault server.

##### Fetching an Example Secret

In this section, you will create an `ExternalSecret`, which is the main resource in the `External Secrets Operator`. The `ExternalSecret` resource tells ESO to fetch a specific secret from a specific `SecretStore` and where to put the information. This resource is very important because it defines what secret you’d like to get from the external secret provider, where to put it, which secret store to use, and how often to sync the secret, among several other options.

Before creating the `ExternalSecret` you need to have a secret available in the `VaultServer`. If you do not have one, follow the next steps:

1. SSH into the Vault Server droplet (if you closed the server you will need to restart the server and unseal it. Steps highlighted in [Step 2](#step-2---configuring-the-vault-server))
2. Create a secret using the following command:

    ```ssh
    vault kv put -mount=secret secret key=secret-value
    ```

    You should see the following output:

    ```text
    Success! Data written to: secret/secret
    ```

A typical `ExternalSecret` configuration looks like below:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <EXTERNAL_SECRET_NAME>
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: <KUBERNETES_SECRET_NAME>
    creationPolicy: Owner
  data:
    - secretKey: <SECRET_KEY>
      remoteRef:
        key: <VAULT_SECRET_KEY>
        property: <VAULT_SECRET_PROPRETY>

```

Explanations for the above configuration:

- `spec.refreshInterval`: How often this secret is synchronized. If the secret's value changes in Vault it will be updated it's Kubernetes counterpart.
- `spec.secretStoreRef`: Referance to the `ClusterSecretStore` resource created earlier.
- `spec.target.name`: Secret to be created in Kuberentes. If not present, then the `secretKey` field under `data` will be used
- `spec.target.creationPolicy`: This will create the secret if it doesn't exist
- `data.[].secretKey`: This is the key inside of the Kubernetes secret that you would like to populate.
- `data.[].remoteRef.key`: This is the remote key in the secret provider. (As an example the previously created secret would be: `secret/secret`)
- `data.[].remoteRef.property`: This is the property inside of the secret at the path specified in in `data.[].remoteRef.key`. (As an example the previously created secret would be: `key`)

Then, open and inspect the `06-kubernetes-secrets/assets/manifests/external-secret.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). Please make sure to replace the `<>` placeholders accordingly:

```shell
code 06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml
```

Next, create the `ExternalSecret` resource:

```shell
kubectl apply -f 06-kubernetes-secrets/assets/manifests/external-secret.yaml
```

This command applies the `ExternalSecret` CRD to your cluster and creates the object. You can see the object by running the following command, which will show you all of the information about the object inside of Kubernetes:

```shell
kubectl get ExternalSecret example-sync
```

You should see something similar to:

```text
NAME           STORE           REFRESH INTERVAL   STATUS         READY
example-sync   vault-backend   15s                SecretSynced   True
```

If the previous output has a `Sync Error` under `STATUS`, nmake sure your `SecretStore` is set up correctly. You can view the actual error by running the following command:

```shell
kubectl get ExternalSecret example-sync -o yaml
```





#### Deploy WordPress on GKE with Cloud SQL


First we need to set up and export some environment variables to Terminal 

export PROJECT_ID="PROJECT_ID"
INSTANCE_NAME="DB_INSTANCE_NAME"
CLOUD_SQL_PASSWORD=Password
SA_NAME=cloudsql-proxy





##### enable the GKE and Cloud SQL Admin APIs


    gcloud services enable container.googleapis.com sqladmin.googleapis.com



Create a PVC And PV  for the storage required for WordPress, You use the wordpress-volumeclaim.yaml  and pv.yaml files to create the PVCs and PV  required for the deployment.

    kind: PersistentVolumeClaim
    apiVersion: v1
    metadata:
     name: wordpress-volumeclaim
    spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 10Gi
    
    
    
    
    
wordpress-volumeclaim.yaml



    apiVersion: v1
    kind: PersistentVolume
    metadata:
     name: pv-volume-3
     labels:
       type: local
    spec:
     storageClassName: standard-rwo
     capacity:
       storage: 20Gi
     accessModes:
       - ReadWriteOnce
     hostPath:
       path: "/home/ubuntu/"
    
pv.yaml


###### deploy the manifest file


    kubectl apply -f wordpress-volumeclaim.yaml    



check the status with the following command:


    kubectl get persistentvolumeclaim 





###### Creating a Cloud SQL for MySQL instance


create an instance named mysql-wordpress-instance


    gcloud sql instances create $INSTANCE_NAME




Add the instance connection name as an environment variable:

    export INSTANCE_CONNECTION_NAME=$(gcloud sql instances describe $INSTANCE_NAME --format='value(connectionName)')    



Create a database for WordPress to store its data:

    gcloud sql databases create wordpress --instance $INSTANCE_NAME





Create a database user called wordpress and a password for WordPress to authenticate to the instance

    gcloud sql users create wordpress --host=% --instance $INSTANCE_NAME \
        --password $CLOUD_SQL_PASSWORD



#### Deploying WordPress
Configure a service account and create secrets
WordPress app access the MySQL instance through a Cloud SQL proxy, create a service account

    gcloud iam service-accounts create $SA_NAME --display-name $SA_NAME

Add the service account email address as an environment variable:

    SA_EMAIL=$(gcloud iam service-accounts list \
    --filter=displayName:$SA_NAME \
    --format='value(email)')



Add the cloudsql.client role to your service account


    gcloud projects add-iam-policy-binding wordpress-393506 \
    --role roles/cloudsql.client \
    --member serviceAccount:$SA_EMAIL



Create a key for the service account

    gcloud iam service-accounts keys create $WORKING_DIR/key.json \
    --iam-account $SA_EMAIL


This command downloads a copy of the key.json file.


Create a Kubernetes secret for the MySQL Username only 

    kubectl create secret generic cloudsql-db-credentials \
    --from-literal username=wordpress -n wordpress



Create a Kubernetes secret for the service account credentials


    kubectl create secret generic cloudsql-instance-credentials \
    --from-file $WORKING_DIR/key.json -n wordpress







The next step is to deploy your WordPress container in the GKE cluster.

***Wordpress_cloudsql.yaml*** manifest file also configures the WordPress container to communicate with MySQL through the Cloud SQL proxy running in the sidecar container. The host address value is set on the WORDPRESS_DB_HOST environment variable

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: wordpress
      labels:
        app: wordpress
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: wordpress
      template:
        metadata:
          labels:
            app: wordpress
        spec:
          containers:
            - image: wordpress
              name: wordpress
              env:
                - name: WORDPRESS_DB_HOST
                  value: 127.0.0.1:3306
                - name: WORDPRESS_DB_USER
                  valueFrom:
                    secretKeyRef:
                      name: mysqlcred-secret
                      key: username
                - name: WORDPRESS_DB_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: mysqlcred-secret
                      key: password
              ports:
                - containerPort: 80
                  name: wordpress
              volumeMounts:
                - name: wordpress-persistent-storage
                  mountPath: /var/www/html
            - name: cloudsql-proxy
              image: gcr.io/cloudsql-docker/gce-proxy:1.33.2
              command: ["/cloud_sql_proxy",
                        "-instances=wordpress-393506:us-central1:mysql-wordpress-instance=tcp:3306",
                        "-credential_file=/secrets/cloudsql/key.json"]
              securityContext:
                runAsUser: 2  # non-root user
                allowPrivilegeEscalation: false
              volumeMounts:
                - name: cloudsql-instance-credentials
                  mountPath: /secrets/cloudsql
                  readOnly: true
          volumes:
            - name: wordpress-persistent-storage
              persistentVolumeClaim:
                claimName: wordpress-volumeclaim
            - name: cloudsql-instance-credentials
              secret:
                secretName: cloudsql-instance-credentials
Wordpress_cloudsql.yaml

Deploy the wordpress_cloudsql.yaml manifest file:

    kubectl create -f wordpress_cloudsql.yaml


Watch the deployment to see the status change to running:

    kubectl get pod -l app=wordpress --watch 



When the output shows a status of Running, you can move on to the next step.


Deployed a WordPress container, but it's currently not accessible from outside your cluster because it doesn't have an external IP address. 
You can expose your WordPress app to traffic from the internet by creating and configuring a Kubernetes Service with an attached external load balancer To learn more about exposing apps using Services in GKE


Create a Service of type:LoadBalancer:

    apiVersion: v1
    kind: Service
    metadata:
     labels:
       app: wordpress
     name: wordpress
    spec:
     type: LoadBalancer
     ports:
       - port: 80
         targetPort: 80
         protocol: TCP
     selector:
       app: wordpress
    
wordpressservice.yaml


    kubectl create -f wordpress-service.yaml 



Watch the deployment and wait for the service to have an external IP address assigned:

    kubectl get svc -l app=wordpress --watch -n wordpress 


When the output shows an external IP address, you can proceed to the next step. Note that your external IP is different from the following example.


##### Setting up your WordPress blog

In your browser, go to the following URL, replacing external-ip-address with the EXTERNAL_IP address of the service that exposes your WordPress instance:


http://external-ip-address



### Refrence 

https://cloud.google.com/kubernetes-engine/docs/tutorials/persistent-disk/

https://earthly.dev/blog/eso-with-hashicorp-vault/#:~:text=An%20External%20Secret%20Operator%20is,system%20like%20AWS%20Secrets%20Manager.

https://www.virtualizationhowto.com/2022/11/install-hashicorp-vault-in-kubernetes/


