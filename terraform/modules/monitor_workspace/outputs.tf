# Output the grafana url for usability
output "grafana_url" {
  value = azurerm_dashboard_grafana.default.endpoint
}