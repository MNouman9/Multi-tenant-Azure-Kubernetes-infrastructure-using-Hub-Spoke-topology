# Create a private Azure Kubernetes Service cluster using Terraform and Azure DevOps #

This code shows how to create a [private AKS clusters](https://docs.microsoft.com/en-us/azure/aks/private-clusters) using:

- [Terraform](https://www.terraform.io/intro/index.html) as infrastructure as code (IaC) tool to build, change, and version the infrastructure on Azure in a safe, repeatable, and efficient way.
- [Azure DevOps Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/what-is-azure-pipelines?view=azure-devops) to automate the deployment and undeployment of the entire infrastructure on multiple environments on the Azure platform.

In a private AKS cluster, the API server endpoint is not exposed via a public IP address. Hence, to manage the API server, you will need to use a virtual machine that has access to the AKS cluster's Azure Virtual Network (VNet). This sample deploys a jumpbox virtual machine in the hub virtual network peered with the virtual network that hosts the private AKS cluster. There are several options for establishing network connectivity to the private cluster.

- Create a virtual machine in the same Azure Virtual Network (VNet) as the AKS cluster.
- Use a virtual machine in a separate network and set up Virtual network peering. See the section below for more information on this option.
- Use an Express Route or VPN connection.

Creating a virtual machine in the same virtual network as the AKS cluster or in a peered virtual network is the easiest option. Express Route and VPNs add costs and require additional networking complexity. Virtual network peering requires you to plan your network CIDR ranges to ensure there are no overlapping ranges. For more information, see [Create a private Azure Kubernetes Service cluster](https://docs.microsoft.com/en-us/azure/aks/private-clusters). For more information on Azure Private Links, see [What is Azure Private Link?](https://docs.microsoft.com/en-us/azure/private-link/private-link-overview)

In addition, the sample creates a private endpoint to access all the managed services deployed by the Terraform modules via a private IP address: 

- Azure Container Registry
- Azure Storage Account
- Azure Key Vault

> **NOTE**  
> If you want to deploy a [private AKS cluster using a public DNS zone](https://docs.microsoft.com/en-us/azure/aks/private-clusters#create-a-private-aks-cluster-with-a-public-dns-address) to simplify the DNS resolution of the API Server to the private IP address of the private endpoint,  you can use this project under my [GitHub](https://github.com/paolosalvatori/private-cluster-with-public-dns-zone) account or on [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates/tree/master/demos/private-aks-cluster-with-public-dns-zone).

## Architecture ##

The following picture shows the high-level architecture created by the Terraform modules included in this sample:

![Architecture](images/normalized-architecture.png)

The following picture provides a more detailed view of the infrastructure on Azure.

![Architecture](images/overall-architecture.png)

The architecture is composed of the following elements:

- A hub virtual network with three subnets:
  - AzureBastionSubnet used by Azure Bastion
  - AzureFirewallSubnet used by Azure Firewall
- A new virtual network with three subnets:
  - SystemSubnet used by the AKS system node pool
  - UserSubnet used by the AKS user node pool
  - VmSubnet used by the jumpbox virtual machine and private endpoints
- The private AKS cluster uses a user-defined managed identity to create additional resources like load balancers and managed disks in Azure.
- The private AKS cluster is composed of a:
  - System node pool hosting only critical system pods and services. The worker nodes have node taint which prevents application pods from beings scheduled on this node pool.
  - User node pool hosting user workloads and artifacts.
- An Azure Firewall used to control the egress traffic from the private AKS cluster. For more information on how to lock down your private AKS cluster and filter outbound traffic, see: 
  - [Control egress traffic for cluster nodes in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic)
  - [Use Azure Firewall to protect Azure Kubernetes Service (AKS) Deployments](https://docs.microsoft.com/en-us/azure/firewall/protect-azure-kubernetes-service)
- An AKS cluster with a private endpoint to the API server hosted by an AKS-managed Azure subscription. The cluster can communicate with the API server exposed via a Private Link Service using a private endpoint.
- An Azure Bastion resource that provides secure and seamless SSH connectivity to the Vm virtual machine directly in the Azure portal over SSL
- An Azure Container Registry (ACR) to build, store, and manage container images and artifacts in a private registry for all types of container deployments.
- When the ACR SKU is equal to Premium, a Private Endpoint is created to allow the private AKS cluster to access ACR via a private IP address. For more information, see [Connect privately to an Azure container registry using Azure Private Link](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-private-link).
- A jumpbox virtual machine used to manage the Azure Kubernetes Service cluster
- A Private DNS Zone for the name resolution of each private endpoint.
- A Virtual Network Link between each Private DNS Zone and both the hub and spoke virtual networks
- A Log Analytics workspace to collect the diagnostics logs and metrics of both the AKS cluster and Vm virtual machine.

## Limitations ##

A private AKS cluster has the following limitations:

- IP authorized ranges can't be applied to the private api server endpoint, they only apply to the public API server
- [Azure Private Link service limitations](https://docs.microsoft.com/en-us/azure/private-link/private-link-service-overview#limitations) apply to private AKS clusters.
- No support for Azure DevOps Microsoft-hosted agents with private clusters. Consider to use [Self-hosted Agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?tabs=browser).
- For customers that need to enable Azure Container Registry to work with private AKS cluster, the Container Registry virtual network must be peered with the agent cluster virtual network.
- No support for converting existing AKS clusters into private clusters
- Deleting or modifying the private endpoint in the customer subnet will cause the cluster to stop functioning.

## Requirements ##

There are some requirements you need to complete before we can deploy Terraform modules using Azure DevOps. 

- Store the Terraform state file to an Azure storage account. For more information on how to create to use a storage account to store remote Terraform state, state locking, and encryption at rest, see [Store Terraform state in Azure Storage](https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage?tabs=azure-cli)
- Create an Azure DevOps Project. For more information, see [Create a project in Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page)
- Create an [Azure DevOps Service Connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints?view=azure-devops&tabs=yaml) to your Azure subscription. No matter you use Service Principal Authentication (SPA) or an Azure-Managed Service Identity when creating the service connection, make sure that the service principal or managed identity used by Azure DevOps to connect to your Azure subscription is assigned the owner role on the entire subscription.

## Fix the routing issue ##

When you deploy an Azure Firewall into a hub virtual network and your private AKS cluster in a spoke virtual network, and you want to use the Azure Firewall to control the egress traffic using network and application rule collections, you need to make sure to properly configure the ingress traffic to any public endpoint exposed by any service running on AKS to enter the system via one of the public IP addresses used by the Azure Firewall. In order to route the traffic of your AKS workloads to the Azure Firewall in the hub virtual network, you need to create and associate a route table to each subnet hosting the worker nodes of your cluster and create a user-defined route to forward the traffic for `0.0.0.0/0` CIDR to the private IP address of the Azure firewall and specify `Virtual appliance` as `next hop type`. For more information, see [Tutorial: Deploy and configure Azure Firewall using the Azure portal](https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-deploy-portal#create-a-default-route).

When you introduce an Azure firewall to control the egress traffic from your private AKS cluster, you need to configure the internet traffic to go throught one of the public Ip address associated to the Azure Firewall in front of the Public Standard Load Balancer used by your AKS cluster. This is where the problem occurs. Packets arrive on the firewall's public IP address, but return to the firewall via the private IP address (using the default route). To avoid this problem, create an additional user-defined route for the firewall's public IP address as shown in the picture below. Packets going to the firewall's public IP address are routed via the Internet. This avoids taking the default route to the firewall's private IP address.

![Firewall](images/firewall-lb-asymmetric.png)

For more information, see:

- [Restrict egress traffic from an AKS cluster using Azure firewall](https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic#restrict-egress-traffic-using-azure-firewall)
- [Integrate Azure Firewall with Azure Standard Load Balancer](https://docs.microsoft.com/en-us/azure/firewall/integrate-lb)

## Terraform State ##

In order to deploy Terraform modules to Azure you can use Azure DevOps CI/CD pipelines. [Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/user-guide/what-is-azure-devops?view=azure-devops) provides developer services for support teams to plan work, collaborate on code development, and build and deploy applications and infrastructure components using IaC technologies such as ARM Templates, Bicep, and Terraform.

Terraform stores [state](https://www.terraform.io/docs/language/state/index.html) about your managed infrastructure and configuration in a special file called state file. This state is used by Terraform to map real-world resources to your configuration, keep track of metadata, and to improve performance for large infrastructures. Terraform state is used to reconcile deployed resources with Terraform configurations. When using Terraform to deploy Azure resources, the state allows Terraform to know what Azure resources to add, update, or delete. By default, Terraform state is stored in a local file named "terraform.tfstate", but it can also be stored remotely, which works better in a team environment. Storing the state in a local file isn't ideal for the following reasons:

- Storing the Terraform state in a local file doesn't work well in a team or collaborative environment.
- Terraform state can include sensitive information.
- Storing state locally increases the chance of inadvertent deletion.

Each Terraform configuration can specify a [backend](https://www.terraform.io/docs/language/settings/backends/index.html), which defines where and how operations are performed, where [state](https://www.terraform.io/docs/language/state/index.html) snapshots are stored. The [Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) or **azurerm** can be used to configure infrastructure in Microsoft Azure using the Azure Resource Manager API's. Terraform provides a [backend](https://www.terraform.io/docs/language/settings/backends/azurerm.html) for the Azure Provider that allows to store the state as a Blob with the given Key within a given Blob Container inside a Blob Storage Account. This backend also supports state locking and consistency checking via native capabilities of the Azure Blob Storage. [](https://www.terraform.io/docs/language/settings/backends/azurerm.html) When using Azure DevOps to deploy services to a cloud environment, you should use this backend to store the state to a remote storage account. For more information on how to create to use a storage account to store remote Terraform state, state locking, and encryption at rest, see [Store Terraform state in Azure Storage](https://docs.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage?tabs=azure-cli). Under the [storage-account](./storage-account) folder in this sample, you can find a Terraform module and bash script to deploy an Azure storage account where you can persist the Terraform state as a blob.

## Azure DevOps Self-Hosted Agent ##

If you plan to use [Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/?view=azure-devops), you can't use [Azure DevOps Microsoft-hosted agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser#microsoft-hosted-agents) to deploy your workloads to a private AKS cluster as they don't have access to its API server. In order to deploy workloads to your private SAKS cluster you need to provision and use an [Azure DevOps self-hosted agent](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser#install) in the same virtual network of your private AKS cluster or in peered virtual network. In this latter case, make sure to the create a virtual network link between the Private DNS Zone of the AKS cluster in the node resource group and the virtual network that hosts the Azure DevOps self-hosted agent. You can deploy a single [Windows](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-windows?view=azure-devops) or [Linux](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) Azure DevOps agent using a virtual machine, or use a virtual machine scale set (VMSS). For more information, see [Azure virtual machine scale set agents](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents?view=azure-devops). For more information, see:

- [Self-hosted Windows agents](/azure/devops/pipelines/agents/v2-windows?view=azure-devops)
- [Self-hosted Linux agents](/azure/devops/pipelines/agents/v2-linux?view=azure-devops)
- [Run a self-hosted agent in Docker](/azure/devops/pipelines/agents/docker?view=azure-devops)

As an alternative, you can set up a self-hosted agent in Azure Pipelines to run inside a Windows Server Core (for Windows hosts), or Ubuntu container (for Linux hosts) with Docker and deploy it as a pod with one or multiple replicas in your private AKS cluster. If the subnets hosting the node pools of your private AKS cluster are configured to route the egress traffic to an Azure Firewall via a route table and user-defined route, make sure to create the proper application and network rules to allow the agent to access external sites to download and install tools like [Docker](https://www.docker.com/), [kubectl](https://kubectl.docs.kubernetes.io/guides/introduction/kubectl/), [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli), and [Helm](https://helm.sh/) to the agent virtual machine. For more informations, see [Run a self-hosted agent in Docker](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/docker?view=azure-devops) and [Build and deploy Azure DevOps Pipeline Agent on AKS](https://github.com/ganrad/Az-DevOps-Agent-On-AKS).

The [cd-self-hosted-agent](./pipelines/cd-self-hosted-agent.yml) pipeline in this sample deploys a [self-hosted Linux agent](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/v2-linux?view=azure-devops) as an Ubuntu Linux virtual machine in the same virtual network hosting the private AKS cluster. The pipeline uses a Terraform module under the [agent](./agent) folder to deploy the virtual machine. Make sure to specify values for the variables in the [cd-self-hosted-agent](./pipelines/cd-self-hosted-agent.yml) and in the [agent.tfvars](./tfvars/agent/agent.tfvars). The following picture represents the network topology of Azure DevOps and self-hosted agent.

![Architecture](images/self-hosted-agent.png)

## Variable Groups ##

The [key-vault](./key-vault) folder contains a bash script that uses Azure CLI to store the following data to an Azure Key Vault. This sensitive data will be used by Azure DevOps CD pipelines via [variable groups](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml). Variable groups store values and secrets that you want to pass into a YAML pipeline or make available across multiple pipelines. You can share use variables groups in multiple pipelines in the same project. You can Link an existing Azure key vault to a variable group and map selective vault secrets to the variable group. You can link an existing Azure Key Vault to a variable group and select which secrets you want to expose as variables in the variable group. For more information, see [Link secrets from an Azure Key Vault](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/variable-groups?view=azure-devops&tabs=yaml#link-secrets-from-an-azure-key-vault).

The YAML pipelines in this sample use a variable group shown in the following picture:

![Variable Group](images/variable-group.png)

The variable group is configured to use the following secrets from an existing Key Vault:

| Variable |Description | 
| :--- | :--- |
| terraformBackendContainerName | Name of the blob container holding the Terraform remote state |
| terraformBackendResourceGroupName | Resource group name of the storage account that contains the Terraform remote state  |
| terraformBackendStorageAccountKey | Key of the storage account that contains the Terraform remote state  |
| terraformBackendStorageAccountName | Name of the storage account that contains the Terraform remote state  |
| sshPublicKey | Key used by Terraform to configure the SSH public key for the administrator user of the virtual machine and AKS worker nodes  |
| azureDevOpsUrl | Url of your Azure DevOps Organization (e.g. https://dev.azure.com/contoso) |
| azureDevOpsPat | Personal access token used by an Azure DevOps self-hosted agent |
| azureDevOpsAgentPoolName | Name of the agent pool of the Azure DevOps self-hosted agent |

## Azure DevOps Pipelines ##

You can use Azure DevOps YAML pipelines to deploy resources to the target environment. Pipelines are part of the same Git repo that contains the artifacts such as Terraform modules and scripts and as such pipelines can be versioned as any other file in the Git reppsitory. You can follow a pull-request process to ensure changes are verified and approved before being merged. The following picture shows the key concepts of an Azure DevOps pipeline.

![Pipeline](images/pipeline.png)

- A [trigger](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#trigger) tells a Pipeline to run.
- A [pipeline](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#pipeline) is made up of one or more [stages](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#stage). A [pipeline](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#pipeline) can deploy to one or more [environments](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#environment).
- A [stage](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#stage) is a way of organizing [jobs](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#job) in a pipeline and each stage can have one or more jobs.
- Each [job](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#job) runs on one [agent](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#agent). A job can also be agentless.
- Each [agent](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#agent) runs a job that contains one or more [steps](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#step).
- A [step](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#step) can be a [task](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#task) or [script](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#script) and is the smallest building block of a pipeline.
- A [task](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#task) is a pre-packaged script that performs an action, such as invoking a REST API or publishing a build artifact.
- An [artifact](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/key-pipelines-concepts?view=azure-devops#artifact) is a collection of files or packages published by a run.

For more information on Azure DevOps pipelines, see: 

- [What is Azure Pipelines?](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/what-is-azure-pipelines?view=azure-devops#:~:text=Azure%20Pipelines%20automatically%20builds%20and,ship%20it%20to%20any%20target.)
- [Add stages, dependencies, & conditions](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/stages?view=azure-devops&tabs=yaml)
- [Specify jobs in your pipeline](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/phases?view=azure-devops&tabs=yaml)

This sample provides pipelines to deploy the infrastructure using Terraform modules, and one to undeploy the infrastructure. 

| Pipeline Name | Description |
| :--- | :--- |
| [create-storage-account_key-vault](./pipelines/1-create-storage-account_key-vault.yml) | This pipeline creates a key avult to store all the secrets to configure to create a Self-Hosted Agent for the subsequent pipelines to run. And it creates a storage account to store the terraform state file. |
| [validate-plan-apply-tfvars](./pipelines/2-validate-plan-apply-tfvars.yml) | In Terraform, to set a large number of variables, you can specify their values in a variable definitions file (with a filename ending in either `.tfvars` or `.tfvars.json`) and then specify that file on the command line with a `-var-file` parameter. For more information, see [Input Variables](https://www.terraform.io/docs/language/values/variables.html). The sample contains three different `.tfvars` files under the [tfvars](./tfvars) folder. Each file contains a different value for each variable and can be used to deploy the same infrastructure to three distinct environment: production, staging, and test. |
| [destroy-aks-deployment](./pipelines/destroy-aks-deployment.yml) | This pipeline uses the [destroy](https://www.terraform.io/docs/cli/commands/destroy.html) command to fully remove the resource group and all the Azure resources. |
## Terraform Extension for Azure DevOps ##

All the pipelines make use of the tasks of the [Terraform](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks) extension. This extension provides the following components:

- A service connection for connecting to an Amazon Web Services(AWS) account
- A service connection for connecting to a Google Cloud Platform(GCP) account
- A task for installing a specific version of Terraform, if not already installed, on the agent
- A task for executing the core Terraform commands

The Terraform tool installer task acquires a specified version of [Terraform](https://www.terraform.io/) from the Internet or the tools cache and prepends it to the PATH of the Azure Pipelines Agent (hosted or private). This task can be used to change the version of Terraform used in subsequent tasks. Adding this task before the [Terraform task](https://github.com/microsoft/azure-pipelines-extensions/tree/master/Extensions/Terraform/Src/Tasks/TerraformTask/TerraformTaskV2) in a build definition ensures you are using that task with the right Terraform version.

The [Terraform task](https://github.com/microsoft/azure-pipelines-extensions/tree/master/Extensions/Terraform/Src/Tasks/TerraformTask/TerraformTaskV2) enables running Terraform commands as part of Azure Build and Release Pipelines providing support for the following Terraform commands

- [init](https://www.terraform.io/docs/cli/commands/init.html)
- [validate](https://www.terraform.io/docs/cli/commands/validate.html)
- [plan](https://www.terraform.io/docs/cli/commands/plan.html)
- [apply](https://www.terraform.io/docs/cli/commands/apply.html)
- [destroy](https://www.terraform.io/docs/cli/commands/destroy.html)

This extension is intended to run on Windows, Linux and MacOS agents. As an alternative, you can use the [Bash Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/bash?
view=azure-devops) or [PowerShell Task](https://docs.microsoft.com/en-us/azure/devops/pipelines/tasks/utility/powershell?view=azure-devops) to install Terraform to the agent and run Terraform commands.

## Azure Resources ##

The following picture shows the resources deployed by the ARM template in the target resource group using one of the Azure DevOps pipelines in this reporitory.

![Resource Group](images/resourcegroup.png)

The following picture shows the resources deployed by the ARM template in the MC resource group associated to the AKS cluster:

![MC Resource Group](images/mc_resourcegroup.png)

## Use Azure Firewall in front of the Public Standard Load Balancer of the AKS cluster ##

Resource definitions in the Terraform modules make use of the [lifecycle](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html) meta-argument to customize the actions when Azure resources are changed outside of Terraform control. The [ignore_changes](https://www.terraform.io/docs/language/meta-arguments/lifecycle.html#ignore_changes) argument is used to instruct Terraform to ignore updates to given resource properties such as tags. The Azure Firewall Policy resource definition contains a lifecycle block to prevent Terraform from fixing the resource when a rule collection or a single rule gets created, updated, or deleted. Likewise, the Azure Route Table contains a lifecycle block to prevent Terraform from fixing the resource when a user-defined route gets created, deleted, or updated. This allows to manage the DNAT, Application, and Network rules of an Azure Firewall Policy and the user-defined routes of an Azure Route Table outside of Terraform control.

The following diagram shows the network topology of the sample:

![Public Standard Load Balancer](images/firewall-public-load-balancer.png)

The message flow can be described as follows:

1. A request for the AKS-hosted web application is sent to a public IP exposed by the Azure Firewall via a public IP configuration. Both the public IP and public IP configuration are dedicated to this workload.
2. An [Azure Firewall DNAT rule](https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-dnat) is used to to translate the Azure Firewall public IP address and port to the public IP and port used by the workload in the `kubernetes` public Standard Load Balancer of the AKS cluster in the node resource group.
3. The request is sent by the load balancer to one of the Kubernetes service pods running on one of the agent nodes of the AKS cluster.
4. The response message is sent back to the original caller via a user-defined with the Azure Firewall public IP as address prefix and Internet as next hope type.
5. Any workload-initiated outbound call is routed to the private IP address of the Azure Firewall by the default user-defined route with `0.0.0.0/0` as address prefix and virtual appliance as next hope type.

## API Gateway ##

In a production environment where Azure Firewall is used to inspect, protect, and filter inbound internet traffic with [Azure Firewall DNAT rules](https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-dnat) and [Threat intelligence-based filtering](https://docs.microsoft.com/en-us/azure/firewall/threat-intel), it's a good practice to use an API Gateway to expose web applications and REST APIs to the public internet.

![Public Standard Load Balancer](images/api-gateway.png)

Without an API gateway, client apps should send requests directly to the Kubernetes-hosted microservices and this would raises the following problems:

- **Coupling**: client application are coupled to internal microservices. Refactoring internal microservices can cause breaking changes to the client apps. Introducing a level of indirection via an API Gateway between client apps and a SaaS application allows you to start breaking down the monolith and gradually replace subsystems  with microservices without violating the contract with client apps.
- **Chattiness**: if a single page/screen needs to retrieve data from multiple microservices, this can result into multiple calls to fine-grained microservices
- **Security issues**:  without an API Gateway, all the microservices are directly exposed to the public internet making the attack surface larger.
- **Cross-cutting concerns**: Each publicly exposed microservice must implement concerns such as authentication, authorization, SSL termination, client rate limiting, response caching, etc.

When running applications on AKS, you can use one of the following API Gateways:

- **Reverse Proxy Server**: [Nginx](https://www.nginx.com/), [HAProxy](https://www.haproxy.com/), and [Traefik](https://traefik.io/) are popular reverse proxy servers that support features such as load balancing, SSL termination, and layer 7 routing. They can run on dedicated virtual machines or as ingress controllers on a Kubernetes cluster.
- **Service Mesh Ingress Controller**: If you are using a service mesh such as [Open Service Mesh](https://openservicemesh.io/), [Linkerd](https://linkerd.io/), and [Istio](https://istio.io/), consider the features that are provided by the ingress controller for that service mesh. For example, the Istio ingress controller supports layer 7 routing, HTTP redirects, retries, and other features.
- **Azure Application Gateway**: [Azure Application Gateway](https://docs.microsoft.com/en-us/azure/application-gateway/overview) is a regional, fully-managed load balancing service that can perform layer-7 routing and SSL termination. It also provides a Web Access Firewall and an [ingress controller](https://docs.microsoft.com/en-us/azure/application-gateway/ingress-controller-overview) for Kubernetes. For more information, see [Use Application Gateway Ingress Controller (AGIC) with a multi-tenant Azure Kubernetes Service](https://docs.microsoft.com/en-us/azure/architecture/example-scenario/aks-agic/aks-agic).
- **Azure Front Door**:  [Azure Front Door](https://docs.microsoft.com/en-us/azure/frontdoor/front-door-overview) is a global layer 7 load balancer that uses the Microsoft global edge network to create fast, secure, and widely scalable web applications. It supports features such as SSL termination, response caching, WAF at the edge, URL-based routing, rewrite and redirections, it support multiple routing methods such as priority routing and latency-based routing.
- **Azure API Management**: [API Management](https://docs.microsoft.com/en-us/azure/api-management/api-management-key-concepts) is a turnkey solution for publishing APIs to both external and internal customers. It provides features that are useful for managing a public-facing API, including rate limiting, IP restrictions, and authentication and authorization using Azure Active Directory or other identity providers.

## Use Azure Firewall in front of an internal Standard Load Balancer ##

In this scenario, an ASP.NET Core application is hosted as a service by an Azure Kubernetes Service cluster and fronted by an [NGINX ingress controller](https://kubernetes.github.io/ingress-nginx/). The application code is available under the [source](./source) folder, while the Helm chart is available in the [chart](./chart) folder. The [NGINX ingress controller](https://kubernetes.github.io/ingress-nginx/) is exposed via an internal load balancer with a private  IP address in the spoke virtual network that hosts the AKS cluster. For more information, see [Create an ingress controller to an internal virtual network in Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/ingress-internal-ip). When you deploy an NGINX ingress controller or more in general a `LoadBalancer` or `ClusterIP` service with the `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` annotation in the metadata section, an internal standard load balancer called `kubernetes-internal` gets created under the node resource group. For more information, see [Use an internal load balancer with Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/internal-lb). As shown in the picture below, the test web application is exposed via the Azure Firewall using a dedicated Azure public IP.  

![Internal Standard Load Balancer](images/firewall-internal-load-balacer.png)

The message flow can be described as follows:

1. A request for the AKS-hosted test web application is sent to a public IP exposed by the Azure Firewall via a public IP configuration. Both the public IP and public IP configuration are dedicated to this workload.
2. An [Azure Firewall DNAT rule](https://docs.microsoft.com/en-us/azure/firewall/tutorial-firewall-dnat) is used to to translate the Azure Firewall public IP address and port to the private IP address and port used by the NGINX ingress conroller in the internal Standard Load Balancer of the AKS cluster in the node resource group.
3. The request is sent by the internal load balancer to one of the Kubernetes service pods running on one of the agent nodes of the AKS cluster.
4. The response message is sent back to the original caller via a user-defined with `0.0.0.0/0` as address prefix and virtual appliance as next hope type.
5. Any workload-initiated outbound call is routed to the private IP address of the user-defined route.
