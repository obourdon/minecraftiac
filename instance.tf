variable "region" {
}

variable "tenancy_ocid" {
}

variable "compartment_ocid" {
}

variable "ssh_public_key" {
}

variable "availability_domain" {
}

provider "oci" {
  region       = var.region
  tenancy_ocid = var.tenancy_ocid
}

# Defines the number of instances to deploy
variable "num_instances" {
  default = "1"
}

# Defines the number of volumes to create and attach to each instance
# NOTE: Changing this value after applying it could result in re-attaching existing volumes to different instances.
# This is a result of using 'count' variables to specify the volume and instance IDs for the volume attachment resource.
variable "num_iscsi_volumes_per_instance" {
  default = "0"
}

variable "num_paravirtualized_volumes_per_instance" {
  default = "0"
}

variable "instance_shape" {
  default = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  default = 4
}

variable "instance_shape_config_memory_in_gbs" {
  default = 24
}

variable "db_size" {
  default = "50" # size in GBs
}


resource "oci_core_instance" "minecraft_instance" {
  count               = var.num_instances
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "MinecraftHashitalkDrift${count.index}"
  shape               = var.instance_shape

  shape_config {
    ocpus = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id                 = oci_core_subnet.minecraft_subnet.id
    display_name              = "Primaryvnic"
    assign_public_ip          = true
    assign_private_dns_record = true
    hostname_label            = "exampleinstance${count.index}"
  }

  source_details {
    source_type = "image"
    source_id = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaajkxjdpgfzjl7tg3a7vzdvwnww6w5k47r5acwe4fqecowqwuoria"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }

  timeouts {
    create = "60m"
  }
}

resource "oci_core_volume_backup_policy_assignment" "policy" {
  count     = var.num_instances
  asset_id  = oci_core_instance.minecraft_instance[count.index].boot_volume_id
  policy_id = data.oci_core_volume_backup_policies.test_predefined_volume_backup_policies.volume_backup_policies[0].id
}

data "oci_core_instance_devices" "minecraft_instance_devices" {
  count       = var.num_instances
  instance_id = oci_core_instance.minecraft_instance[count.index].id
}

data "oci_core_volume_backup_policies" "test_predefined_volume_backup_policies" {
  filter {
    name = "display_name"

    values = [
      "silver",
    ]
  }
}

# Output the private and public IPs of the instance

output "instance_private_ips" {
  value = [oci_core_instance.minecraft_instance.*.private_ip]
}

output "instance_public_ips" {
  value = [oci_core_instance.minecraft_instance.*.public_ip]
}

# Output the boot volume IDs of the instance
output "boot_volume_ids" {
  value = [oci_core_instance.minecraft_instance.*.boot_volume_id]
}

# Output all the devices for all instances
output "instance_devices" {
  value = [data.oci_core_instance_devices.minecraft_instance_devices.*.devices]
}


output "silver_policy_id" {
  value = data.oci_core_volume_backup_policies.test_predefined_volume_backup_policies.volume_backup_policies[0].id
}

/*
output "attachment_instance_id" {
  value = data.oci_core_boot_volume_attachments.test_boot_volume_attachments.*.instance_id
}
*/

resource "oci_core_vcn" "minecraft_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "TestVcn"
  dns_label      = "testvcn"
}

resource "oci_core_internet_gateway" "minecraft_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "TestInternetGateway"
  vcn_id         = oci_core_vcn.minecraft_vcn.id
}

resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.minecraft_vcn.default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.minecraft_internet_gateway.id
  }
}

resource "oci_core_subnet" "minecraft_subnet" {
  availability_domain = var.availability_domain
  cidr_block          = "10.1.20.0/24"
  display_name        = "TestSubnet"
  dns_label           = "testsubnet"
  security_list_ids   = [oci_core_vcn.minecraft_vcn.default_security_list_id, oci_core_security_list.minecraft_security_list.id]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.minecraft_vcn.id
  route_table_id      = oci_core_vcn.minecraft_vcn.default_route_table_id
  dhcp_options_id     = oci_core_vcn.minecraft_vcn.default_dhcp_options_id
}

resource "oci_core_security_list" "minecraft_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.minecraft_vcn.id
  display_name   = "MinecraftSecurityList"

  // allow inbound ssh traffic from a specific port
  ingress_security_rules {
    protocol  = "6" // tcp
    source    = "0.0.0.0/0"
    stateless = false

    tcp_options {

      // These values correspond to the destination port range.
      min = 25565
      max = 25565
    }
  }

  ingress_security_rules {
    protocol  = "17" // udp
    source    = "0.0.0.0/0"
    stateless = false

    udp_options {

      // These values correspond to the destination port range.
      min = 25565
      max = 25565
    }
  }
}

