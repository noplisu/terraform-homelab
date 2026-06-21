locals {
  homepage_config_src          = "${path.module}/../stacks/homepage/config"
  homepage_config_remote_path  = "/volume1/docker/homepage/config"
  homepage_config_staging_path = "/volume1/docker/homepage/.terraform-sync/config"
  homepage_nginx_src           = "${path.module}/../stacks/homepage/nginx"
  homepage_nginx_remote_path   = "/volume1/docker/homepage/nginx"
  homepage_nginx_staging_path  = "/volume1/docker/homepage/.terraform-sync/nginx"
  nas_provisioner_script_path  = "/volume1/docker/.terraform-provisioner.sh"
  nas_docker_bin               = "/usr/local/bin/docker"
  # terraform user needs sudo for docker on Synology; base64 avoids shell escaping the password
  nas_docker                   = "echo ${base64encode(var.nas_ssh_password)} | base64 -d | sudo -S ${local.nas_docker_bin}"
}

resource "null_resource" "homepage_config" {
  triggers = {
    sync_hash = sha256(join(",", concat(
      [for f in sort(fileset(local.homepage_config_src, "**")) : filesha256("${local.homepage_config_src}/${f}")],
      [for f in sort(fileset(local.homepage_nginx_src, "**")) : filesha256("${local.homepage_nginx_src}/${f}")],
    )))
    sync_mode = "bridge-network-v3"
  }

  connection {
    type        = "ssh"
    host        = var.nas_lan_ip
    user        = var.nas_ssh_user
    port        = var.nas_ssh_port
    password    = var.nas_ssh_password
    script_path = local.nas_provisioner_script_path
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${local.homepage_config_staging_path} ${local.homepage_nginx_staging_path}",
      "mkdir -p ${local.homepage_config_remote_path} ${local.homepage_nginx_remote_path}",
    ]
  }

  provisioner "file" {
    source      = "${local.homepage_config_src}/"
    destination = "${local.homepage_config_staging_path}/"
  }

  provisioner "file" {
    source      = "${local.homepage_nginx_src}/"
    destination = "${local.homepage_nginx_staging_path}/"
  }

  provisioner "remote-exec" {
    inline = [
      "if ${local.nas_docker} ps --format '{{.Names}}' | grep -qx homepage-nginx; then",
      "  ${local.nas_docker} stop homepage-nginx",
      "fi",
      "${local.nas_docker} run --rm -v ${local.homepage_config_staging_path}:/src:ro -v ${local.homepage_config_remote_path}:/dst alpine:3.20 sh -c 'cp -rf /src/. /dst/'",
      "${local.nas_docker} run --rm -v ${local.homepage_nginx_staging_path}:/src:ro -v ${local.homepage_nginx_remote_path}:/dst alpine:3.20 sh -c 'cp -f /src/default.conf /dst/default.conf'",
      "if ${local.nas_docker} ps -a --format '{{.Names}}' | grep -qx homepage-nginx; then",
      "  ${local.nas_docker} start homepage-nginx",
      "fi",
      "if ${local.nas_docker} ps --format '{{.Names}}' | grep -qx homepage; then",
      "  ${local.nas_docker} restart homepage",
      "  ${local.nas_docker} restart homepage-nginx",
      "fi",
    ]
  }
}
