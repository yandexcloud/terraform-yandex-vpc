variable "name" {
  type        = string
  description = "Name prefix for resources to be created"
}

variable "description" {
  default     = ""
  description = "VPC description"
}

variable "env" {
  type        = string
  description = "Environment name"
}

variable "zones" {
  default     = ["ru-central1-a", "ru-central1-b", "ru-central1-c"]
  description = "Yandex zones where subnets will be created"
}

variable "network_cidr" {
  default     = "10.0.0.0/16"
  description = "Base CIDR for subnets inside VPC"
}

variable "subnet_mask" {
  default     = 8
  description = "Mask to be used when generating subnet CIDR blocks"
}

variable "nat_sa" {
  type        = string
  description = "Service account ID for NAT instance"
}

variable "nat_ssh_key" {
  type        = string
  description = "Public SSH key to place in NAT instance's authorized keys"
}

variable "nat_image" {
  type        = string
  description = "Name of VM image which is configured as NAT"
}

variable "nat_platform_id" {
  default     = "standard-v2"
  description = "NAT instance platform ID"
}

variable "nat_cores" {
  default     = 2
  description = "Number of CPU cores used in NAT instance"
}

variable "nat_memory" {
  default     = 0.5
  description = "Amount of RAM in GB used in NAT instance"
}

variable "nat_core_fraction" {
  default     = 5
  description = "CPU cores fraction in persents"
}

variable "nat_disk_type" {
  default     = "network-hdd"
  description = "Type of boot disk used in NAT instance (network-hdd or network-ssd)"
}

variable "nat_disk_size" {
  default     = 1
  description = "Boot disk size used in NAT instance"
}

variable "nat_preemptible" {
  default     = true
  description = "Indicates whether NAT instances will be preemptible"
}
