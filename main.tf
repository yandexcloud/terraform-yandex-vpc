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

  labels = {
    env  = var.env
    vpc  = yandex_vpc_network.vpc.name
    zone = var.zones[count.index]
  }

  lifecycle {
    # NOTE: static routes are managed by NAT instances.
    ignore_changes = [static_route]
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

resource "yandex_compute_instance_group" "nat" {
  count              = length(var.zones)
  name               = "${var.name}-nat-${var.zones[count.index]}"
  service_account_id = var.nat_sa

  instance_template {
    name               = "${var.name}-nat-{instance.zone_id}-{instance.index_in_zone}"
    hostname           = "${var.name}-nat-{instance.zone_id}-{instance.index_in_zone}"
    platform_id        = var.nat_platform_id
    service_account_id = var.nat_sa

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
      subnet_ids = [yandex_vpc_subnet.nat[count.index].id]
      nat        = true
    }

    labels = {
      env  = var.env
      vpc  = yandex_vpc_network.vpc.name
      zone = var.zones[count.index]
    }

    metadata = {
      user-data = yandex_vpc_route_table.nat[count.index].id
      ssh-keys  = var.nat_ssh_key
    }

    network_settings {
      type = "STANDARD"
    }

    scheduling_policy {
      preemptible = var.nat_preemptible
    }
  }

  allocation_policy {
    zones = [var.zones[count.index]]
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 1
  }
}
