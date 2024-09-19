resource "yandex_kubernetes_node_group" "k8s-demo-ng" {
  name        = var.node_group_name
  description = "Test node group"
  cluster_id  = yandex_kubernetes_cluster.k8s-zonal.id
  version     = "1.27"
  instance_template {
    name        = "test-{instance.short_id}-{instance_group.id}"
    platform_id = "standard-v3"
    resources {
      cores         = var.node_number_cores
      core_fraction = var.node_core_fraction
      memory        = var.node_size_ram
    }
    boot_disk {
      size = var.node_size_ssd
      type = "network-ssd"
    }
    network_acceleration_type = "standard"
    network_interface {
      security_group_ids = ["${yandex_vpc_security_group.k8s-public-services.id}"]
      subnet_ids         = ["${yandex_vpc_subnet.mysubnet.id}"]
      nat                = true
    }
    scheduling_policy {
      preemptible = true
    }
  }
  scale_policy {
    fixed_scale {
      size = var.node_scale_size
    }
  }
  deploy_policy {
    max_expansion   = var.node_max_expansion
    max_unavailable = var.node_max_unavailable
  }
  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
    maintenance_window {
      start_time = "22:00"
      duration   = "10h"
    }
  }
  node_labels = {
    node-label1 = "${var.node_lables_for_grouping_k8s}"
  }

  labels = {
    "template-label1" = "${var.node_label}"
  }
  allowed_unsafe_sysctls = ["kernel.msg*", "net.core.somaxconn"]
}
