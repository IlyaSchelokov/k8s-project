output "public_ip_k8s-master" {
  value = [yandex_compute_instance.master.network_interface.0.nat_ip_address]
}

output "internal_ip_k8s-master" {
  value = [yandex_compute_instance.master.network_interface.0.ip_address]
}

output "internal_ip_node1" {
  value = [yandex_compute_instance.node1.network_interface.0.ip_address]
}

output "internal_ip_node2" {
  value = [yandex_compute_instance.node2.network_interface.0.ip_address]
}

output "internal_ip_vm" {
  value = [yandex_compute_instance.vm.network_interface.0.ip_address]
}

output "load_balancer_public_ip" {
  value = yandex_lb_network_load_balancer.grafana.listener.*.external_address_spec[0].*.address
}
