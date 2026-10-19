# Recursos — az-03 (VNet, NSG, ASG, Private Link, Hub-Spoke)

## Documentación oficial

- [Azure Virtual Network — overview](https://learn.microsoft.com/azure/virtual-network/virtual-networks-overview)
- [Subnet address space and reserved IPs](https://learn.microsoft.com/azure/virtual-network/virtual-network-manage-subnet)
- [Network Security Groups — how they work](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [Application Security Groups](https://learn.microsoft.com/azure/virtual-network/application-security-groups)
- [Effective security rules on a NIC](https://learn.microsoft.com/azure/virtual-network/diagnose-network-traffic-filter-problem)
- [Service Endpoints — overview](https://learn.microsoft.com/azure/virtual-network/virtual-network-service-endpoints-overview)
- [Private Endpoint — overview](https://learn.microsoft.com/azure/private-link/private-endpoint-overview)
- [Private Link — overview](https://learn.microsoft.com/azure/private-link/private-link-overview)
- [Private DNS Zones for Private Endpoints](https://learn.microsoft.com/azure/private-link/private-endpoint-dns)
- [NAT Gateway — overview](https://learn.microsoft.com/azure/nat-gateway/nat-overview)
- [VNet Peering — overview](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
- [Hub-spoke network topology (CAF)](https://learn.microsoft.com/azure/architecture/networking/architecture/hub-spoke)
- [Azure Virtual WAN — overview](https://learn.microsoft.com/azure/virtual-wan/virtual-wan-about)
- [Azure Firewall — overview](https://learn.microsoft.com/azure/firewall/overview)
- [Application Gateway (incluye WAF)](https://learn.microsoft.com/azure/application-gateway/overview)
- [Azure Load Balancer](https://learn.microsoft.com/azure/load-balancer/load-balancer-overview)
- [Azure Front Door — overview](https://learn.microsoft.com/azure/frontdoor/front-door-overview)
- [Azure Bastion — overview](https://learn.microsoft.com/azure/bastion/bastion-overview)

## Terraform provider `azurerm`

- [azurerm_virtual_network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
- [azurerm_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)
- [azurerm_network_security_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group)
- [azurerm_network_security_rule](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_rule)
- [azurerm_application_security_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_security_group)
- [azurerm_private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint)
- [azurerm_private_dns_zone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone)
- [azurerm_private_dns_zone_virtual_network_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link)
- [azurerm_nat_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/nat_gateway)
- [azurerm_virtual_network_peering](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering)

## Reference architectures

- [Cloud Adoption Framework — Network topology (CAF LZ)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/define-an-azure-network-topology)
- [AzureCAT reference: hub-spoke with Azure Firewall](https://learn.microsoft.com/azure/architecture/networking/architecture/hub-spoke-vnet-peering)
- [Enterprise-scale landing zone — networking](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/network-topology-and-connectivity)

## Lecturas comparativas AWS ↔ Azure

- [AWS to Azure services comparison (networking)](https://learn.microsoft.com/azure/architecture/aws-professional/networking)
- [VPC vs VNet — differences at a glance](https://learn.microsoft.com/azure/architecture/aws-professional/services#networking-and-content-delivery)
