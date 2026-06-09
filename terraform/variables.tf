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