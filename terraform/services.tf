resource "cloudflare_dns_record" "books" {
  zone_id = var.cloudflare_zone_id
  name    = "books"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_dns_record" "gitea" {
  zone_id = var.cloudflare_zone_id
  name    = "gitea"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
