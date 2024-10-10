resource "yandex_resourcemanager_folder" "myfolder" {
  # Создание в облаке YC папки для размещения ресурсов.
  cloud_id    = local.cloud_id
  name        = var.folder_name
  description = "myfolder"
}

resource "yandex_vpc_network" "mynet" {
  # Создание внутренней сети кластера и его компонентов.
  name      = var.net_name
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_subnet" "mysubnet1" {
  # Создание внутренней подсети кластера и его компонентов.
  name           = var.subnet_name_basic
  v4_cidr_blocks = ["192.168.10.0/27"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mynet.id
  folder_id      = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_subnet" "mysubnet2" {
  # Создание внутренней подсети кластера и его компонентов.
  name           = var.subnet_name_for_pods
  v4_cidr_blocks = ["10.112.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mynet.id
  folder_id      = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_subnet" "mysubnet3" {
  # Создание внутренней подсети кластера и его компонентов.
  name           = var.subnet_name_for_services
  v4_cidr_blocks = ["10.96.0.0/16"]
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.mynet.id
  folder_id      = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_security_group" "sec-group" {
  # Создание группы безопасности для разграничения сетевого доступа к кластеру и его компонентам".
  name        = var.sec-group_name
  description = "Правила группы разрешают подключение к сервисам из интернета."
  network_id  = yandex_vpc_network.mynet.id
  folder_id   = yandex_resourcemanager_folder.myfolder.id

  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера Managed Service for Kubernetes и сервисов балансировщика."
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
    description    = "Правило разрешает взаимодействие под-под и сервис-сервис. Укажите подсети вашего кластера Managed Service for Kubernetes и сервисов."
    v4_cidr_blocks = concat(yandex_vpc_subnet.mysubnet1.v4_cidr_blocks)
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
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавьте или измените порты на нужные вам."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Yandex Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик ssh."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }
  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает 3000 port."
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
  name                      = var.master_name
  hostname                  = "master.test.internal"
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
    subnet_id          = yandex_vpc_subnet.mysubnet1.id
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
  name                      = var.node1_name
  hostname                  = "node1.test.internal"
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
    subnet_id          = yandex_vpc_subnet.mysubnet1.id
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
  name                      = var.node2_name
  hostname                  = "node2.test.internal"
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
    subnet_id          = yandex_vpc_subnet.mysubnet1.id
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
  name                      = var.vm_name
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
    subnet_id          = yandex_vpc_subnet.mysubnet1.id
    security_group_ids = [yandex_vpc_security_group.sec-group.id]
  }

  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }

  labels = {
    "template-label1" = "vm"
  }
}

resource "yandex_lb_target_group" "grafana" {
  name      = "grafana"
  folder_id = yandex_resourcemanager_folder.myfolder.id
  target {
    subnet_id = yandex_vpc_subnet.mysubnet1.id
    address   = yandex_compute_instance.node1.network_interface.0.ip_address
  }
  target {
    subnet_id = yandex_vpc_subnet.mysubnet1.id
    address   = yandex_compute_instance.node2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "grafana" {
  name      = "grafana"
  folder_id = yandex_resourcemanager_folder.myfolder.id
  listener {
    name        = "grafana"
    port        = 3000
    target_port = 32000
    protocol    = "tcp"
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.grafana.id
    healthcheck {
      name                = "tcp"
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2
      tcp_options {
        port = 22
      }
    }
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
  content = templatefile("./templates/inventory.tftpl",
    {
      master = yandex_compute_instance.master.network_interface.0.nat_ip_address
      node1  = yandex_compute_instance.node1.network_interface.0.nat_ip_address
      node2  = yandex_compute_instance.node2.network_interface.0.nat_ip_address
      vm     = yandex_compute_instance.vm.network_interface.0.nat_ip_address
  })
  filename = "./ansible-install-k8s/inventory.ini"
}

# Создание scrapeconfig
resource "local_file" "scrape_config" {
  depends_on = [
    yandex_compute_instance.vm
  ]
  content = templatefile("./templates/scrapeconfig.tftpl",
    {
      vm     = yandex_compute_instance.vm.network_interface.0.nat_ip_address
  })
  filename = "./ansible-install-k8s/roles/9_install-scrapeconfig/files/scrapeconfig.yaml"
}

# Проверка соединения для последующего выполнения плейбука
resource "terraform_data" "execute-playbook" {
  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      host        = yandex_compute_instance.master.network_interface.0.nat_ip_address
      user        = var.user_name
      agent       = false
      private_key = file(var.private_key)
    }
    inline = ["echo '!!!connected!!!'"]
  }
  depends_on = [
    local_file.ansible_inventory
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i ./ansible-install-k8s/inventory.ini --private-key ${var.private_key} ./ansible-install-k8s/ans-k8s.yaml"
  }
}
