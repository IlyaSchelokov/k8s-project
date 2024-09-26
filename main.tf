resource "yandex_resourcemanager_folder" "myfolder" {
  # Создание в облаке YC папки для размещения ресурсов.
  cloud_id    = local.cloud_id
  name        = "tomatos"
  description = "myfolder"
}

resource "yandex_vpc_network" "mynet" {
  # Создание внутренней сети кластера и его компонентов.
  name      = "mynet"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_subnet" "mysubnet" {
  # Создание внутренней подсети кластера и его компонентов.
  name           = "mysubnet"
  v4_cidr_blocks = ["192.168.10.0/27"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mynet.id
  folder_id      = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_security_group" "sec-group" {
  # Создание группы безопасности для разграничения сетевого доступа к кластеру и его компонентам".
  name        = "sec-group"
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
    description    = "Правило разрешает входящий трафик на 3000 port."
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

resource "yandex_compute_disk" "disk-master-1" {
  name      = "disk-master-1"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "master-1" {
  # Создание k8s-master-1.
  name                      = "master-1"
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
    disk_id = yandex_compute_disk.disk-master-1.id
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
    "template-label1" = "master-1"
  }
}

resource "yandex_compute_disk" "disk-node-3" {
  name      = "disk-node-3"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "node-3" {
  # Создание первой ноды.
  name                      = "node-3"
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
    disk_id = yandex_compute_disk.disk-node-3.id
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
    "template-label1" = "node-3"
  }
}

resource "yandex_compute_disk" "disk-node-4" {
  name      = "disk-node-4"
  type      = "network-ssd"
  zone      = "ru-central1-a"
  size      = "12"
  image_id  = "fd8d75k8a0dldkad633n"
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_compute_instance" "node-4" {
  # Создание второй ноды.
  name                      = "node-4"
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
    disk_id = yandex_compute_disk.disk-node-4.id
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
    "template-label1" = "node-4"
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
  name                      = "vm"
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
    yandex_compute_instance.master-1,
    yandex_compute_instance.node-3,
    yandex_compute_instance.node-4,
    yandex_compute_instance.vm
  ]
  content = templatefile("./hosts.ini",
    {
      master-1 = yandex_compute_instance.master-1.network_interface.0.nat_ip_address
      node-3   = yandex_compute_instance.node-3.network_interface.0.nat_ip_address
      node-4   = yandex_compute_instance.node-4.network_interface.0.nat_ip_address
      vm       = yandex_compute_instance.vm.network_interface.0.nat_ip_address
  })
  filename = "./ansible-install-k8s/inventory.ini"
}

# Проверка соединения для последующего выполнения плейбука
resource "terraform_data" "execute-playbook" {
  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      host        = yandex_compute_instance.master-1.network_interface.0.nat_ip_address
      user        = "ilya"
      agent       = false
      private_key = file(var.private_key)
    }
    inline = ["echo 'connected!'"]
  }
  depends_on = [
    local_file.ansible_inventory
  ]

  ### пока в работе ###
  #  provisioner "local-exec" {
  #    command = "ansible-playbook -i ./ansible-install-k8s/inventory.ini --private-key ${var.private_key} ./ansible-install-k8s/ans-k8s.yaml"
  #  }
}
