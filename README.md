# Мое тестовое задание
Требуется:
- создать один кластер Kubernetes и одну виртуальную машину в публичном облаке
- развернуть стек мониторинга в созданном Kubernetes кластере и настроить сбор/хранение/отображение основных метрик кластера и виртуальной машины

## Стек:
Yandex Cloud/Kubernetes/Linux/Terraform/Prometheus/Grafana

## Начальные параметры:
- создан аккаунт в Yandex Cloud
- на рабочую машину установлены: Terraform, kubectl, Helm, Yandex Cloud (CLI)
- заранее созданы конфигурационные файлы grafana.yaml и cloud-config.yaml
- получен OAuth токен аккаунта в Yandex Cloud
- настроен профиль в Yandex Cloud (CLI)

## Развертывание Terraform сценария
1. Склонируйте репозиторий `IlyaSchelokov/k8s-project` из GitHub и перейдите в папку сценария `k8s-project`:
    ```bash
    git clone https://github.com/IlyaSchelokov/k8s-project.git
    cd k8s-project
    ```
2. Выполните инициализацию Terraform:
    ```bash
    terraform init
    ```
3. Проверьте конфигурацию Terraform файлов:
    ```bash
    terraform validate
    ```
4. Проверьте список создаваемых облачных ресурсов:
    ```bash
    terraform plan
    ```
5. Создайте ресурсы. На развертывание всех ресурсов в облаке потребуется около 15 мин:
    ```bash
    terraform apply
    ```
6. После завершения процесса terraform apply в командной строке будет выведен список информации о развернутых ресурсах. В дальнейшем его можно будет посмотреть с помощью команды `terraform output`:

    <details>
    <summary>Посмотреть информацию о развернутых ресурсах</summary>

    | Название | Описание |
    | ----------- | ----------- |
    | `internal_ip_k8s` | Внутренний IP-адрес кластера k8s
    | `public_ip_k8s` | Публичный IP-адрес кластера k8s
    | `internal_ip_VM` | Внутренний IP-адрес виртуальной машины
    | `public_ip_VM` | Публичный IP-адрес кластера виртуальной машины

    </details>

## Действия после развертывания сценария
1. Чтобы получить учетные данные для подключения к публичному IP-адресу кластера через Интернет, выполните команду:
    ```bash
    yc managed-kubernetes cluster get-credentials <имя_или_идентификатор_кластера> --external
    ```
2. Установите Prometheus
   ```bash
   helm install my-prom prometheus-community/prometheus
   ```
3. Для отправки метрик из виртуальной машины в Grafana подключитесь к ВМ, используя публичный IP ВМ, установите и запустите на ВМ node_exporter: 
   ```bash
   wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
   ```
   ```bash
   tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz
   ```   
   ```bash
   cd node_exporter-1.8.2.linux-amd64
   ```   
   ```bash
   ./node_exporter
   ```
4. Добавьте в конфигурационный файл prometheus.yml данные для сбора метрик с виртуальной машины:
   ```bash
   KUBE_EDITOR="nano -c" kubectl edit configmap my-prom-prometheus-server -n default
   ```
    ```bash
    - job_name: my-vm
      metrics_path: /metrics
      static_configs:
        - targets: ["<внутренний IP-адрес ВМ>:9100"]
    ```
5. Установите Grafana
   ```bash
   kubectl apply -f grafana.yaml
   ```
6. Подключитесь к Grafana:
 - узнайте внешний IP-адрес сетевого балансировщика:
   ```bash
   yc load-balancer network-load-balancer list --folder-name <имя папки YC, в которой создан проект k8s>
   yc load-balancer network-load-balancer get --id <идентификатор балансировщика, полученный командой выше>
   ```
 - выполните вход в Grafana:
   ```bash
   URL — http://<внешний IP-адрес балансировщика>:3000
   Логин и пароль: admin
   ```
8. Добавьте источник данных с типом Prometheus и необходимыми настройками. Для этого:
 - получите список всех созданных подов:
   ```bash
   kubectl get pods
   ```
 - узнайте внутренний IP-адрес пода с сервером Prometheus:
   ```bash
   kubectl describe pods/my-prom-prometheus-server
   ```
 - добавьте источник:
   ```bash
   Name — Prometheus.
   URL — http://<внутренний IP-адрес пода сервера Prometheus>:9090
   ```
10. Импортируйте дашборды:
   - Kubernetes cluster monitoring (via Prometheus), содержащий метрики кластера Kubernetes. Укажите идентификатор дашборда (315) при импорте.
   - Kubernetes Nodes, содержащий основные метрики нод Kubernetes и виртуальной машины. Укажите идентификатор дашборда (8171) при импорте.

11. Откройте дашборды и убедитесь, что Grafana получает метрики от кластера Kubernetes, от нод кластера и виртуальной машины.
12. Для удаления созданных ресурсов используйте:
    ```bash
    terraform destroy
    ```
