data "portainer_environment" "synology" {
  name = "local"   # exact name from Portainer → Environments
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