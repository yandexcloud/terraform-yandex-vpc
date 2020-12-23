terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

locals {
  nat_offset = 0

  nat_cidrs = [
    for i in range(length(var.zones)) : cidrsubnet(
      var.network_cidr,
      var.subnet_mask,
      local.nat_offset + i + 1,
    )
  ]

  nat_ips = [for i in range(length(var.zones)) : cidrhost(
    local.nat_cidrs[i],
    pow(2, var.subnet_mask) - 2
  )]

  net_offset = length(var.zones) * 1

  net_cidrs = [
    for i in range(length(var.zones)) : cidrsubnet(
      var.network_cidr,
      var.subnet_mask,
      local.net_offset + i + 1,
    )
  ]
}

resource "yandex_vpc_network" "vpc" {
  name        = var.name
  description = var.description

  labels = {
    env = var.env
  }
}

resource "yandex_vpc_subnet" "nat" {
  count          = length(var.zones)
  zone           = var.zones[count.index]
  name           = "${var.name}-pub-${var.zones[count.index]}"
  network_id     = yandex_vpc_network.vpc.id
  v4_cidr_blocks = local.nat_cidrs

  labels = {
    env  = var.env
    vpc  = yandex_vpc_network.vpc.name
    zone = var.zones[count.index]
    nat  = false
  }
}

resource "yandex_vpc_route_table" "nat" {
  count      = length(var.zones)
  network_id = yandex_vpc_network.vpc.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = local.nat_ips[count.index]
  }

  labels = {
    env  = var.env
    vpc  = yandex_vpc_network.vpc.name
    zone = var.zones[count.index]
  }
}

resource "yandex_vpc_subnet" "net" {
  count          = length(var.zones)
  zone           = var.zones[count.index]
  name           = "${var.name}-pri-${var.zones[count.index]}"
  network_id     = yandex_vpc_network.vpc.id
  route_table_id = yandex_vpc_route_table.nat[count.index].id
  v4_cidr_blocks = local.net_cidrs

  labels = {
    env  = var.env
    vpc  = yandex_vpc_network.vpc.name
    zone = var.zones[count.index]
    nat  = true
  }
}

data "yandex_compute_image" "nat" {
  name = var.nat_image
}

resource "yandex_compute_instance" "nat" {
  count                     = length(var.zones)
  name                      = "${var.name}-nat-${var.zones[count.index]}"
  hostname                  = "${var.name}-nat-${var.zones[count.index]}"
  service_account_id        = var.nat_sa
  platform_id               = var.nat_platform_id
  allow_stopping_for_update = true

  resources {
    cores         = var.nat_cores
    memory        = var.nat_memory
    core_fraction = var.nat_core_fraction
  }

  boot_disk {
    mode = "READ_WRITE"
    initialize_params {
      image_id = data.yandex_compute_image.nat.id
      size     = var.nat_disk_size
      type     = var.nat_disk_type
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.nat[count.index].id
    ip_address = local.nat_ips[count.index]
    nat        = true
  }

  labels = {
    env  = var.env
    vpc  = yandex_vpc_network.vpc.name
    zone = var.zones[count.index]
  }

  metadata = {
    ssh-keys = var.nat_ssh_key
  }
}
