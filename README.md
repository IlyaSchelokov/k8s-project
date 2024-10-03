# Мое тестовое задание
Требуется:
- создать один кластер Kubernetes и одну виртуальную машину в публичном облаке
- развернуть стек мониторинга в созданном Kubernetes кластере и настроить сбор/хранение/отображение основных метрик кластера и виртуальной машины

## Стек:
Yandex Cloud/Kubernetes/Ubuntu/Terraform/Prometheus/Grafana/Ansible/Docker

## Требования:
- python 3.8.10
- terraform 1.9.6

## Развертывание Terraform сценария
1. Склонируйте репозиторий `IlyaSchelokov/k8s-project` из GitHub и перейдите в папку сценария `k8s-project`:
    ```bash
    git clone https://github.com/IlyaSchelokov/k8s-project.git
    cd k8s-project
    ```
2. Файлы *.example необходимо заполнить своими значениями, после - переименовать, убрав ".example"
3. Для возможности подключения к созданным ВМ необходимо сгенерировать пару ssh-ключей:
   ```bash
   ssh-keygen -t ed25519
   ```
4. Установите необходимую версию Ansible:
   ```bash
   pip install -r requirements.txt
   ```
5. Добавьте в PATH директорию с Ansible:
   ```bash
   export PATH=$PATH:/home/<имя_пользователя>/.local/bin
   ```
6. Сгенерируйте конфигурацию Ansible:
   ```bash
   ansible-config init --disabled > ansible.cfg 
   ```
7. Для отключения проверки по fingerprint для Ansible установите host_key_checking=False в ansible.cfg
8. Установите необходимые коллекции Ansible с помощью Ansible Galaxy CLI:
   ```bash
   ansible-galaxy install -r ansible-install-k8s/requirements.yml
   ```
9. Для настройки Terraform требуется указать источник, из которого будет устанавливаться провайдер
   
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
10. Вернитесь в каталог k8s-project и выполните инициализацию Terraform:
    ```bash
    terraform init
    ```    
11. Проверьте конфигурацию Terraform файлов:
    ```bash
    terraform validate
    ```
12. Проверьте список создаваемых облачных ресурсов:
    ```bash
    terraform plan
    ```
13. Создайте ресурсы. На развертывание всех ресурсов в облаке потребуется около 20 мин:
    ```bash
    terraform apply -auto-approve
    ```
14. После завершения процесса terraform apply -auto-approve в командной строке будет выведен список информации о развернутых ресурсах. В дальнейшем его можно будет посмотреть с помощью команды `terraform output`:

    <details>
    <summary>Посмотреть информацию о развернутых ресурсах</summary>

    | Название | Описание |
    | ----------- | ----------- |
    | `public_ip_k8s-master` | Публичный IP-адрес k8s-master
    | `internal_ip_k8s-master` | Внутренний IP-адрес k8s-master
    | `internal_ip_node1` | Внутренний IP-адрес node1
    | `internal_ip_node2` | Внутренний IP-адрес node2
    | `internal_ip_vm` | Внутренний IP-адрес vm

    </details>

15. Перейдите в Grafana:
    ```bash
      http://<public_ip_k8s-master>:3000
    ```
    Откройте дашборды и убедитесь, что Grafana получает метрики от внутренних IP адресов мастера, двух нод Kubernetes и виртуальной машины.

16. Для удаления созданных ресурсов используйте:
    ```bash
    terraform destroy
    ```
