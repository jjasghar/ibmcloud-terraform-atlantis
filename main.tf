locals {
  BASENAME = "asgharlabs"
  ZONE     = "us-south-1"
  LOCATION = "us-south"
}

variable "name" {
  default = "cluster"
}

variable "cluster_name" {
  default = "cluster-vpc"
}

variable "number" {
  default = "1"
}

variable "kube_version" {
  default = "1.19.4"
}

variable "flavor" {
  default = "bx2.4x16"
}

variable "worker_count" {
  default = "3"
}

variable "zone" {
  default = "us-south-1"
}

variable "service_instance_name" {
  default = "my-service-instance"
}

variable "worker_pool_name" {
  default = "terraform-vpc2pool"
}

variable "resource_group" {
  default = "Default"
}

variable "region" {
  default = "us-south"
}

resource "random_id" "random" {
  byte_length = 2
}

resource "ibm_is_vpc" "vpc" {
  name = "${local.BASENAME}-vpc-${random_id.random.hex}"
}

resource "ibm_is_security_group" "sg1" {
  name = "${local.BASENAME}-sg1"
  vpc  = ibm_is_vpc.vpc.id
}

data "ibm_resource_group" "resource_group" {
  name = var.resource_group
}

resource "ibm_resource_instance" "kms_instance1" {
    name              = "test_kms"
    service           = "kms"
    plan              = "tiered-pricing"
    location          = "us-south"
}

resource "ibm_kms_key" "test" {
    instance_id = ibm_resource_instance.kms_instance1.guid
    key_name = "test_root_key"
    standard_key =  false
    force_delete = true
}

resource "ibm_container_vpc_cluster" "cluster" {
  name              = "${var.cluster_name}-${count.index}"
  vpc_id            = ibm_is_vpc.vpc.id
  kube_version      = var.kube_version
  flavor            = var.flavor
  count             = var.number
  worker_count      = var.worker_count
  wait_till         = "OneWorkerNodeReady"
  resource_group_id = data.ibm_resource_group.resource_group.id
  tags              = [var.cluster_name,"terraform"]

  zones {
    subnet_id = ibm_is_subnet.subnet1.id
    name      = local.ZONE
  }

  kms_config {
    instance_id = ibm_resource_instance.kms_instance1.guid
    crk_id = ibm_kms_key.test.key_id
    private_endpoint = false
  }
}

# If you want to add another pool
# resource "ibm_container_vpc_worker_pool" "cluster_pool" {
#   cluster           = ibm_container_vpc_cluster.cluster.id
#   worker_pool_name  = "${var.worker_pool_name}${random_id.name1.hex}"
#   flavor            = var.flavor
#   vpc_id            = ibm_is_vpc.vpc1.id
#   worker_count      = var.worker_count
#   resource_group_id = data.ibm_resource_group.resource_group.id
#   zones {
#     name      = local.ZONE
#     subnet_id = ibm_is_subnet.subnet1.id
#   }
# }

# per http://ibm.biz/vpc-sgs
resource "ibm_is_security_group_rule" "ping_ingress_traffic_118_rule" {
  group     = ibm_is_security_group.sg1.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  icmp {
    type = 8
  }
}

resource "ibm_is_security_group_rule" "tcp_ingress_traffic_118_rule" {
  group     = ibm_is_security_group.sg1.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  tcp {
    port_min = 30000
    port_max = 32767
  }
}

resource "ibm_is_security_group_rule" "udp_ingress_traffic_118_rule" {
  group     = ibm_is_security_group.sg1.id
  direction = "inbound"
  remote    = "0.0.0.0/0"
  udp {
    port_min = 30000
    port_max = 32767
  }
}

resource "ibm_is_security_group_rule" "outbound_26_traffic_118_rule" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"
  remote    = "161.26.0.0/16"
}

resource "ibm_is_security_group_rule" "outbound_8_traffic_118_rule" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"
  remote    = "166.8.0.0/14"
}

resource "ibm_is_security_group_rule" "egress_all_all" {
  group     = ibm_is_security_group.sg1.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}

resource "ibm_is_subnet" "subnet1" {
  name                     = "${local.BASENAME}-subnet1"
  vpc                      = ibm_is_vpc.vpc.id
  zone                     = local.ZONE
  total_ipv4_address_count = 256
}

resource "ibm_resource_instance" "cos_instance" {
  name     = "${var.service_instance_name}-${count.index}"
  service  = "cloud-object-storage"
  plan     = "standard"
  location = "global"
  count    = var.number
}

resource "ibm_container_bind_service" "bind_service" {
  cluster_name_id     = ibm_container_vpc_cluster.cluster[count.index].id
  service_instance_id = element(split(":", ibm_resource_instance.cos_instance[count.index].id), 7)
  namespace_id        = "default"
  role                = "Writer"
  count               = var.number
}

# cluster config file path
#output "cluster_config_file_path" {
#  value = data.ibm_container_cluster_config.cluster_config.config_file_path
#}
#data "ibm_container_cluster_config" "cluster_config" {
#  cluster_name_id = ibm_container_vpc_cluster.cluster.id
#}
