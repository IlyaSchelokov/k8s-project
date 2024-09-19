resource "yandex_resourcemanager_folder" "myfolder" {
  # Создание в облаке YC папки для размещения ресурсов.
  cloud_id    = local.cloud_id
  name        = var.my_folder
  description = "myfolder"
}

resource "yandex_kubernetes_cluster" "k8s-zonal" {
  # Создание кластера k8s.
  name       = var.k8s_name
  network_id = yandex_vpc_network.mynet.id
  folder_id  = yandex_resourcemanager_folder.myfolder.id
  master {
    master_location {
      zone      = yandex_vpc_subnet.mysubnet.zone
      subnet_id = yandex_vpc_subnet.mysubnet.id
    }
    public_ip = true
  }
  service_account_id      = yandex_iam_service_account.myaccount.id
  node_service_account_id = yandex_iam_service_account.myaccount.id
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-clusters-agent,
    yandex_resourcemanager_folder_iam_member.vpc-public-admin,
    yandex_resourcemanager_folder_iam_member.images-puller,
    yandex_resourcemanager_folder_iam_member.encrypterDecrypter,
    yandex_resourcemanager_folder_iam_member.load-balancer-admin
  ]
  kms_provider {
    key_id = yandex_kms_symmetric_key.kms-key.id
  }
}

resource "yandex_vpc_network" "mynet" {
  # Создание внутренней сети кластера и его компонентов.
  name      = var.k8s_net_name
  folder_id = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_subnet" "mysubnet" {
  # Создание внутренней подсети кластера и его компонентов.
  name           = var.k8s_subnet_name
  v4_cidr_blocks = ["192.168.10.0/27"]
  zone           = var.k8s_zone_name
  network_id     = yandex_vpc_network.mynet.id
  folder_id      = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_iam_service_account" "myaccount" {
  # Создание сервисного аккаунта для взаимодействия с кластером k8s и его компонентами.
  name        = var.k8s_sa_account
  description = "K8S zonal service account"
  folder_id   = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_resourcemanager_folder_iam_member" "k8s-clusters-agent" {
  # Сервисному аккаунту назначается роль "k8s.clusters.agent".
  folder_id = yandex_resourcemanager_folder.myfolder.id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc-public-admin" {
  # Сервисному аккаунту назначается роль "vpc.publicAdmin".
  folder_id = yandex_resourcemanager_folder.myfolder.id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "images-puller" {
  # Сервисному аккаунту назначается роль "container-registry.images.puller".
  folder_id = yandex_resourcemanager_folder.myfolder.id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "encrypterDecrypter" {
  # Сервисному аккаунту назначается роль "kms.keys.encrypterDecrypter".
  folder_id = yandex_resourcemanager_folder.myfolder.id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "load-balancer-admin" {
  # Сервисному аккаунту назначается роль "load-balancer.admin".
  folder_id = yandex_resourcemanager_folder.myfolder.id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.myaccount.id}"
}

resource "yandex_kms_symmetric_key" "kms-key" {
  # Ключ Yandex Key Management Service для шифрования важной информации, такой как пароли, OAuth-токены и SSH-ключи.
  name              = var.k8s_name_kms_key
  default_algorithm = "AES_128"
  rotation_period   = "8760h" # 1 год.
  folder_id         = yandex_resourcemanager_folder.myfolder.id
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  # Создание группы безопасности для разграничения сетевого доступа к кластеру и его компонентам".
  name        = var.k8s_name_sec_group
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
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Yandex Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}
