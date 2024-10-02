# Мое тестовое задание
Требуется:
- создать один кластер Kubernetes и одну виртуальную машину в публичном облаке
- развернуть стек мониторинга в созданном Kubernetes кластере и настроить сбор/хранение/отображение основных метрик кластера и виртуальной машины

## Стек:
Yandex Cloud/Kubernetes/Ubuntu/Terraform/Prometheus/Grafana/Ansible/Docker

## Требования:
- python 3.8.10

## Развертывание Terraform сценария
1. Склонируйте репозиторий `IlyaSchelokov/k8s-project` из GitHub и перейдите в папку сценария `k8s-project`:
    ```bash
    git clone https://github.com/IlyaSchelokov/k8s-project.git
    cd k8s-project
    ```
2. Файлы *.example необходимо заполнить своими значениями, после - переименовать, убрав ".example"    
3. Установите необходимые коллекции Ansible с помощью Ansible Galaxy CLI:
   ```bash
   ansible-galaxy install -r ansible-install-k8s/requirements.yml
   ```
4. Для отключения проверки по fingerprint для Ansible раскомментируйте строку #host_key_checking = False в ansible.cfg.
5. Для настройки Terraform требуется указать источник, из которого будет устанавливаться провайдер
   
   - перейдите в домашний каталог пользователя:
   ```bash
   cd /home/<имя пользователя>/
   ```
   - создайте файл конфигурации:
   ```bash
   nano ~/.terraformrc
   ```
   - добавьте в него следующий блок:
   ```bash
     provider_installation {
    network_mirror {
      url = "https://terraform-mirror.yandexcloud.net/"
      include = ["registry.terraform.io/*/*"]
    }
    direct {
      exclude = ["registry.terraform.io/*/*"]
     }
   }
   ```      
6. Выполните инициализацию Terraform:
    ```bash
    terraform init
    ```    
7. Проверьте конфигурацию Terraform файлов:
    ```bash
    terraform validate
    ```
8. Проверьте список создаваемых облачных ресурсов:
    ```bash
    terraform plan
    ```
9. Создайте ресурсы. На развертывание всех ресурсов в облаке потребуется около 20 мин:
    ```bash
    terraform apply -auto-approve
    ```
10. После завершения процесса terraform apply -auto-approve в командной строке будет выведен список информации о развернутых ресурсах. В дальнейшем его можно будет посмотреть с помощью команды `terraform output`:

    <details>
    <summary>Посмотреть информацию о развернутых ресурсах</summary>

    | Название | Описание |
    | ----------- | ----------- |
    | `public_ip_k8s-master` | Публичный IP-адрес k8s-master

    </details>

11. Перейдите в Grafana:
    ```bash
      http://<public_ip_k8s-master>:3000
    ```
    Откройте дашборды и убедитесь, что Grafana получает метрики от кластера Kubernetes и виртуальной машины.

12. Для удаления созданных ресурсов используйте:
    ```bash
    terraform destroy
    ```
