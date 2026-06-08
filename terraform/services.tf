resource "cloudflare_record" "homelab" {
  zone_id = var.cloudflare_zone_id
  name    = "books"
  type    = "CNAME"
  value   = cloudflare_zero_trust_tunnel_cloudflared.homelab.cname
  proxied = true
}
