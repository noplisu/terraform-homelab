terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    portainer = {
      source  = "portainer/portainer"
      version = "~> 1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "portainer" {
  endpoint        = var.portainer_url
  api_key         = var.portainer_api_key
  skip_ssl_verify = true   # common on Synology self-signed certs
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
