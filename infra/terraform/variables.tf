variable "cluster_domain" {
  description = "Domain name for the cluster (e.g., pi.local or subdomain.duckdns.org)"
  type        = string
  default     = "pi.local"
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@example.com"
}

variable "duckdns_token" {
  description = "DuckDNS token for DNS challenge (if using DuckDNS)"
  type        = string
  default     = "YOUR_DUCKDNS_TOKEN_HERE"
  sensitive   = true
}

variable "storage_retention_days" {
  description = "Data retention period in days"
  type        = number
  default     = 30
}

variable "resource_limits" {
  description = "Resource limits for Pi-friendly deployments"
  type = object({
    prometheus_storage = string
    loki_storage       = string
    postgres_storage   = string
    cpu_limit          = string
    memory_limit       = string
  })
  default = {
    prometheus_storage = "3Gi"
    loki_storage       = "2Gi"
    postgres_storage   = "2Gi"
    cpu_limit          = "500m"
    memory_limit       = "512Mi"
  }
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}

variable "monitoring_config" {
  description = "Monitoring and alerting configuration"
  type = object({
    cpu_threshold_percent    = number
    memory_threshold_percent = number
    disk_threshold_percent   = number
    alert_duration           = string
  })
  default = {
    cpu_threshold_percent    = 70
    memory_threshold_percent = 80
    disk_threshold_percent   = 85
    alert_duration           = "10m"
  }
}
