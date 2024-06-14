output "id" {
  description = "Specifies the The ID of the NAT Gateway."
  value       = azurerm_nat_gateway.nat_gateway.id
}

output "resource_guid" {
  description = "Specifies the The resource GUID property of the NAT Gateway.."
  value       = azurerm_nat_gateway.nat_gateway.resource_guid
}