resource "yandex_resourcemanager_folder" "myfolder" {
  # Создание в облаке YC папки для размещения ресурсов.
  cloud_id    = local.cloud_id
  name        = "${var.folder_name}"
  description = "myfolder"
}

resource "yandex_vpc_network" "mynet" {
  # Создание внутренней сети кластера и его компонентов.
  name      = "${var.net_name}"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_subnet" "mysubnet" {
  # Создание внутренней подсети кластера и его компонентов.
  name           = "${var.subnet_name}"
  v4_cidr_blocks = ["192.168.10.0/27"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mynet.id
  folder_id      = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_security_group" "sec-group" {
  # Создание группы безопасности для разграничения сетевого доступа к кластеру и его компонентам".
  name        = "${var.sec-group_name}"
  description = "Правила группы разрешают подключение к сервисам из интернета."
  network_id  = yandex_vpc_network.mynet.id
  folder_id   = yandex_resourcemanager_folder.myfolder.id

  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol       = "ANY"
    description    = "Правило разрешает взаимодействие под-под и сервис-сервис."
    v4_cidr_blocks = concat(yandex_vpc_subnet.mysubnet.v4_cidr_blocks)
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "ICMP"
    description    = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
    ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик ssh."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
    ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик ssh."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Yandex Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_compute_disk" "disk-master" {
  name      = "disk-master"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "master" {
  # Создание k8s-master.
  name                      = "${var.master_name}"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true
  folder_id                 = yandex_resourcemanager_folder.myfolder.id
  resources {
    cores         = 4
    memory        = 4 # GB
    core_fraction = 20
  }

  boot_disk {
    disk_id = yandex_compute_disk.disk-master.id
  }

  network_interface {
    nat                = true # Создание внешнего IP ВМ.
    subnet_id          = yandex_vpc_subnet.mysubnet.id
    security_group_ids = [yandex_vpc_security_group.sec-group.id]
  }

  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }

  labels = {
    "template-label1" = "master"
  }
}

resource "yandex_compute_disk" "disk-node1" {
  name      = "disk-node1"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "node1" {
  # Создание первой ноды.
  name                      = "${var.node1_name}"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true
  folder_id                 = yandex_resourcemanager_folder.myfolder.id
  resources {
    cores         = 4
    memory        = 4 # GB
    core_fraction = 20
  }

  boot_disk {
    disk_id = yandex_compute_disk.disk-node1.id
  }

  network_interface {
    nat                = true # Создание внешнего IP ВМ.
    subnet_id          = yandex_vpc_subnet.mysubnet.id
    security_group_ids = [yandex_vpc_security_group.sec-group.id]
  }

  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }

  labels = {
    "template-label1" = "node1"
  }
}

resource "yandex_compute_disk" "disk-node2" {
  name      = "disk-node2"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "node2" {
  # Создание второй ноды.
  name                      = "${var.node2_name}"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true
  folder_id                 = yandex_resourcemanager_folder.myfolder.id
  resources {
    cores         = 4
    memory        = 4 # GB
    core_fraction = 20
  }

  boot_disk {
    disk_id = yandex_compute_disk.disk-node2.id
  }

  network_interface {
    nat                = true # Создание внешнего IP ВМ.
    subnet_id          = yandex_vpc_subnet.mysubnet.id
    security_group_ids = [yandex_vpc_security_group.sec-group.id]
  }

  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }

  labels = {
    "template-label1" = "node2"
  }
}

resource "yandex_compute_disk" "disk-vm" {
  name      = "disk-vm"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "vm" {
  # Создание виртуальной машины.
  name                      = "${var.vm_name}"
  platform_id               = "standard-v1"
  zone                      = "ru-central1-a"
  allow_stopping_for_update = true
  folder_id                 = yandex_resourcemanager_folder.myfolder.id
  resources {
    cores         = 2
    memory        = 2 # GB
    core_fraction = 20
  }

  boot_disk {
    disk_id = yandex_compute_disk.disk-vm.id
  }

  network_interface {
    nat                = true # Создание внешнего IP ВМ.
    subnet_id          = yandex_vpc_subnet.mysubnet.id
    security_group_ids = [yandex_vpc_security_group.sec-group.id]
  }

  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }

  labels = {
    "template-label1" = "vm"
  }
}

# Создание ansible inventory
resource "local_file" "ansible_inventory" {
  depends_on = [
    yandex_compute_instance.master,
    yandex_compute_instance.node1,
    yandex_compute_instance.node2,
    yandex_compute_instance.vm
  ]
  content = templatefile("./hosts.ini",
    {
      master = yandex_compute_instance.master.network_interface.0.nat_ip_address
      node1   = yandex_compute_instance.node1.network_interface.0.nat_ip_address
      node2   = yandex_compute_instance.node2.network_interface.0.nat_ip_address
      vm       = yandex_compute_instance.vm.network_interface.0.nat_ip_address
  })
  filename = "./ansible-install-k8s/inventory.ini"
}

# Создание prometheus config
resource "local_file" "prometheus_config" {
  depends_on = [
    yandex_compute_instance.master,
    yandex_compute_instance.node1,
    yandex_compute_instance.node2,
    yandex_compute_instance.vm
  ]
  content = templatefile("./prom_conf.tftpl",
    {
      master = yandex_compute_instance.master.network_interface.0.ip_address
      node1   = yandex_compute_instance.node1.network_interface.0.ip_address
      node2   = yandex_compute_instance.node2.network_interface.0.ip_address
      vm       = yandex_compute_instance.vm.network_interface.0.ip_address
  })
  filename = "./ansible-install-k8s/roles/7_prometheus-grafana/files/prometheus_main.yml"
}

# Создание grafana config
resource "local_file" "grafana_config" {
  depends_on = [
    yandex_compute_instance.master
  ]
  content = templatefile("./graf_conf.tftpl",
    {
      master = yandex_compute_instance.master.network_interface.0.ip_address
  })
  filename = "./ansible-install-k8s/roles/7_prometheus-grafana/files/grafana/provisioning/datasources/all.yml"
}


# Проверка соединения для последующего выполнения плейбука
resource "terraform_data" "execute-playbook" {
  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      host        = yandex_compute_instance.master.network_interface.0.nat_ip_address
      user        = "ilya"
      agent       = false
      private_key = file(var.private_key)
    }
    inline = ["echo 'connected!'"]
  }
  depends_on = [
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i ./ansible-install-k8s/inventory.ini --private-key ${var.private_key} ./ansible-install-k8s/ans-k8s.yaml"
  }
}

output "public_ip_k8s-master" {
  value = [yandex_compute_instance.master.network_interface.0.nat_ip_address]
}
