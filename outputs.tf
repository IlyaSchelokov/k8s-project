output "internal_ip_k8s" {
  value = [yandex_kubernetes_cluster.k8s-zonal.master.0.internal_v4_address]
}

output "public_ip_k8s" {
  value = [yandex_kubernetes_cluster.k8s-zonal.master.0.external_v4_address]
}

output "internal_ip_VM" {
  value = [yandex_compute_instance.my-vm.network_interface.0.ip_address]
}

output "public_ip_VM" {
  value = [yandex_compute_instance.my-vm.network_interface.0.nat_ip_address]
}


#output "LB" {
#  value = [yandex_lb_network_load_balancer.default.external_address_spec.0.address]
#}

