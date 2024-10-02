# Мое тестовое задание
Требуется:
- создать один кластер Kubernetes и одну виртуальную машину в публичном облаке
- развернуть стек мониторинга в созданном Kubernetes кластере и настроить сбор/хранение/отображение основных метрик кластера и виртуальной машины

## Стек:
Yandex Cloud/Kubernetes/Ubuntu/Terraform/Prometheus/Grafana/Ansible/Docker

## Требования:
- python v3.8.10

## Развертывание Terraform сценария
1. Склонируйте репозиторий `IlyaSchelokov/k8s-project` из GitHub и перейдите в папку сценария `k8s-project`:
    ```bash
    git clone https://github.com/IlyaSchelokov/k8s-project.git
    cd k8s-project
    ```
2. Установите необходимые коллекции Ansible с помощью Ansible Galaxy CLI:
   ```bash
   ansible-galaxy install -r ./ansible-install-k8s/requirements.yml
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
5. Создайте ресурсы. На развертывание всех ресурсов в облаке потребуется около 20 мин:
    ```bash
    terraform apply -auto-approve
    ```
6. После завершения процесса terraform apply в командной строке будет выведен список информации о развернутых ресурсах. В дальнейшем его можно будет посмотреть с помощью команды `terraform output`:

    <details>
    <summary>Посмотреть информацию о развернутых ресурсах</summary>

    | Название | Описание |
    | ----------- | ----------- |
    | `public_ip_k8s-master` | Публичный IP-адрес k8s-master

    </details>

7. Перейдите в Grafana:
    ```bash
      http://<public_ip_k8s-master>:3000
    ```
   Откройте дашборды и убедитесь, что Grafana получает метрики от кластера Kubernetes и виртуальной машины.

8. Для удаления созданных ресурсов используйте:
    ```bash
    terraform destroy
    ```
