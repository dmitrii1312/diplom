provider "yandex" {
  cloud_id = "b1gdi5987arb0pnup4lj"
  folder_id = "b1gud7usbuekc5a56rtd"
  zone = "ru-central1-a"
}

locals {
  domain = "dmitrii.website"
  domain_name = "dmitrii-website-zone"
  vm_maps = {
    "db01" = {
      stage = {
        cpu = 2
        mem = 2
      }
      prod = {
        cpu = 2
        mem = 2
      }
    }
    "db02" = {
      stage = {
        cpu = 2
        mem = 2
      }
      prod = {
        cpu = 2
        mem = 2
      }
    }
    "monitoring" = {
      stage = {
        cpu = 4
        mem = 4
      }
      prod = {
        cpu = 4
        mem = 4
      }
    }
    "gitlab" = {
      stage = {
        cpu = 4
        mem = 4
      }
      prod = {
        cpu = 4
        mem = 4
      }
    }
    "runner" = {
      stage = {
        cpu = 4
        mem = 4
      }
      prod = {
        cpu = 4
        mem = 4
      }
    }
    "app" = {
      stage = {
        cpu = 4
        mem = 4
      }
      prod = {
        cpu = 4
        mem = 4
      }
    }
    "nginx" = {
      stage = {
        cpu = 2
        mem = 2
      }
      prod = {
        cpu = 2
        mem = 2
      }
    }
  }

  zones = {
    "ru-central1-a" = "192.168.50.0/24"
    "ru-central1-b" = "192.168.51.0/24"
    "ru-central1-c" = "192.168.52.0/24"
  }
  extnames_map = {
    "www" = "app"
    "gitlab" = "gitlab"
    "grafana" = "monitoring"
    "prometheus" = "monitoring"
    "alertmanager" = "monitoring"
  }
  local_port_map = {
    "www" = 80
    "gitlab" = 80
    "grafana" = 3000
    "prometheus" = 9090
    "alertmanager" = 9093
  }
  default_zone = "ru-central1-a"
  reverse_proxy = "nginx"
}
resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet1" {
  for_each = local.zones
  name = "subnet-${each.key}"
  zone = each.key
  network_id = yandex_vpc_network.network1.id
  v4_cidr_blocks = [each.value]
}
data "yandex_compute_image" "cpuimage" {
  name = "ubuntu2004"
}
resource "yandex_compute_instance" "vms" {
  for_each = local.vm_maps
  name = "${each.key}"
  zone = local.default_zone
  
  resources {
    cores = each.value[terraform.workspace].cpu
    memory = each.value[terraform.workspace].mem
  }
  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.cpuimage.id}"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1[local.default_zone].id
    nat = true
  }
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
data "yandex_dns_zone" "dns_zone" {
  name = "${local.domain_name}"
}
resource "yandex_dns_recordset" "dns_records" {
  for_each = local.extnames_map
  zone_id = data.yandex_dns_zone.dns_zone.id
  name = "${each.key}"
  type = "A"
  ttl = 600
  data = ["${yandex_compute_instance.vms["${local.reverse_proxy}"].network_interface.0.nat_ip_address}"]
}
resource "local_file" "hosts_cfg" {
  for_each = local.vm_maps
  content = "[${each.key}]\n${yandex_compute_instance.vms["${each.key}"].network_interface.0.ip_address} ansible_ssh_common_args='-o ProxyCommand=\"ssh -W %h:%p -q ubuntu@www.${local.domain}\"'\n"
  filename = "inventory/${each.key}"
}
resource "local_file" "var_cfg" {
  content = "domain_name: \"${local.domain}\"\nlocaladdress:\n%{ for vm in yandex_compute_instance.vms }  ${vm.name}: ${vm.network_interface.0.ip_address}\n%{ endfor ~}sites:\n%{ for key, value in local.extnames_map ~}- name: ${key}\n  address: \"{{ localaddress.${value} }}\"\n  port: ${lookup(local.local_port_map, "${key}")}\n%{ endfor ~}\n%{ for key, value in local.extnames_map ~}${key}_url: ${value}.${local.domain}\n%{ endfor ~}"
  filename = "inventory/group_vars/all/vars.yml"
}
