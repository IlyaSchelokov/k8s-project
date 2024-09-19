resource "yandex_vpc_security_group" "vm-security-group" {
  # Создание группы безопасности для подключения к ВМ извне.
  name        = var.vm_name_sec_group
  description = "Security group for the VM"
  network_id  = yandex_vpc_network.mynet.id
  folder_id   = yandex_resourcemanager_folder.myfolder.id

  ingress {
    description    = "Allows connections to the VM via SSH"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "my-vm" {
  # Создание виртуальной машины.
  name                      = var.vm_name
  platform_id               = "standard-v1"
  zone                      = var.vm_zone_name
  allow_stopping_for_update = true
  folder_id                 = yandex_resourcemanager_folder.myfolder.id
  resources {
    cores         = var.vm_number_cores
    memory        = var.vm_size_ram # GB
    core_fraction = var.vm_core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.vm_image_id # Образ the Ubuntu 22.04.
    }
  }

  network_interface {
    nat       = true # Создание внешнего IP ВМ.
    subnet_id = yandex_vpc_subnet.mysubnet.id
  }


  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }
}
