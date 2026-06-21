data "portainer_environment" "synology" {
  name = "local"   # exact name from Portainer → Environments
}

locals {
  homepage_lan_host = var.homepage_lan_hostname != "" ? var.homepage_lan_hostname : var.nas_lan_ip
  homepage_allowed_hosts = join(",", concat(
    [
      var.nas_lan_ip,
      "${var.nas_lan_ip}:7575",
      "localhost",
      "localhost:7575",
    ],
    var.homepage_lan_hostname != "" ? [var.homepage_lan_hostname, "${var.homepage_lan_hostname}:7575"] : [],
  ))
}

resource "portainer_docker_network" "homelab" {
  name        = "homelab"
  endpoint_id = data.portainer_environment.synology.id
  driver      = "bridge"
}

resource "portainer_stack" "stump" {
  name            = "stump"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/stump/docker-compose.yml"

  depends_on = [portainer_docker_network.homelab]
}

resource "portainer_stack" "gitea" {
  name            = "gitea"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/gitea/docker-compose.yml"

  env {
    name  = "GITEA_ROOT_URL"
    value = "https://gitea.${var.domain}/"
  }

  depends_on = [portainer_docker_network.homelab]
}

resource "portainer_stack" "rustdesk" {
  name            = "rustdesk"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/rustdesk/docker-compose.yml"
}

resource "portainer_stack" "yopass" {
  name            = "yopass"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/yopass/docker-compose.yml"
  pull_image      = true
  prune           = true

  env {
    name  = "YOPASS_MEMCACHED"
    value = "yopass-memcached:11211"
  }

  depends_on = [portainer_docker_network.homelab]
}

resource "portainer_stack" "homepage" {
  name            = "homepage"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/homepage/docker-compose.yml"
  pull_image      = true

  env {
    name  = "HOMEPAGE_ALLOWED_HOSTS"
    value = local.homepage_allowed_hosts
  }

  env {
    name  = "HOMEPAGE_VAR_DOMAIN"
    value = var.domain
  }

  env {
    name  = "HOMEPAGE_VAR_NAS_IP"
    value = var.nas_lan_ip
  }

  env {
    name  = "HOMEPAGE_VAR_LAN_HOST"
    value = local.homepage_lan_host
  }

  env {
    name  = "HOMEPAGE_VAR_QC_HOST"
    value = var.synology_quickconnect_host
  }

  env {
    name  = "HOMEPAGE_VAR_PORTAINER_ENV"
    value = data.portainer_environment.synology.id
  }

  env {
    name  = "HOMEPAGE_VAR_PORTAINER_KEY"
    value = var.portainer_api_key
  }

  depends_on = [null_resource.homepage_config]
}

resource "portainer_stack" "gateway" {
  name            = "gateway"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/gateway/docker-compose.yml"
  pull_image      = true

  depends_on = [
    null_resource.gateway_config,
    portainer_stack.homepage,
  ]
}

resource "portainer_stack" "cloudflared" {
  name            = "cloudflared"
  deployment_type = "standalone"
  method          = "file"
  endpoint_id     = data.portainer_environment.synology.id
  stack_file_path = "${path.module}/../stacks/cloudflared/docker-compose.yml"

  env {
    name  = "TUNNEL_TOKEN"
    value = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  }

  depends_on = [
    portainer_docker_network.homelab,
    cloudflare_zero_trust_tunnel_cloudflared_config.homelab,
    portainer_stack.stump,
  ]
}