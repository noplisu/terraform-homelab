locals {
  gateway_nginx_tpl          = "${path.module}/../stacks/gateway/nginx/default.conf.tpl"
  gateway_nginx_remote_file  = "/volume1/docker/gateway/nginx/default.conf"
  gateway_nginx_staging_file = "/volume1/docker/gateway/.terraform-sync/nginx/default.conf"
}

resource "local_file" "gateway_nginx" {
  content = templatefile(local.gateway_nginx_tpl, {
    nas_lan_ip = var.nas_lan_ip
  })
  filename = "${path.module}/.generated/gateway-default.conf"
}

resource "null_resource" "gateway_config" {
  triggers = {
    sync_hash = local_file.gateway_nginx.content_md5
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
      "mkdir -p $(dirname ${local.gateway_nginx_staging_file})",
      "mkdir -p $(dirname ${local.gateway_nginx_remote_file})",
      "if ${local.nas_docker} ps --format '{{.Names}}' | grep -qx gateway-nginx; then",
      "  ${local.nas_docker} stop gateway-nginx",
      "fi",
    ]
  }

  provisioner "file" {
    source      = local_file.gateway_nginx.filename
    destination = local.gateway_nginx_staging_file
  }

  provisioner "remote-exec" {
    inline = [
      "${local.nas_docker} run --rm -v $(dirname ${local.gateway_nginx_staging_file}):/src:ro -v $(dirname ${local.gateway_nginx_remote_file}):/dst alpine:3.20 sh -c 'cp -f /src/default.conf /dst/default.conf'",
      "if ${local.nas_docker} ps -a --format '{{.Names}}' | grep -qx gateway-nginx; then",
      "  ${local.nas_docker} start gateway-nginx",
      "fi",
    ]
  }

  depends_on = [local_file.gateway_nginx]
}
