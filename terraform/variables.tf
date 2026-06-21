variable "cloudflare_account_id" {
  type = string
  sensitive = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "portainer_url" {
  type = string
}

variable "portainer_api_key" {
  type = string
  sensitive = true
}

variable "nas_lan_ip" {
  type        = string
  description = "Synology LAN IP — used for Homepage LAN links, allowed hosts, and SSH sync"
}

variable "nas_ssh_user" {
  type        = string
  description = "SSH user on the Synology NAS (used to sync Homepage config)"
}

variable "nas_ssh_password" {
  type        = string
  description = "SSH password for the Synology NAS (Homepage config sync). Do not commit."
  sensitive   = true
}

variable "nas_ssh_port" {
  type        = number
  description = "SSH port on the NAS"
  default     = 22
}

variable "synology_quickconnect_host" {
  type        = string
  description = "Synology QuickConnect direct hostname (without https://)"
}

variable "homepage_lan_hostname" {
  type        = string
  description = "LAN hostname for Homepage and dashboard links. Empty falls back to nas_lan_ip."
}
