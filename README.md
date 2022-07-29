## Диплом
### 1. Зарегистрировать доменное имя (любое на ваш выбор в любой доменной зоне).
На nic.ru зарегистрировано доменное имя dmitrii.website. В личном кабинете не nic.ru появилась возможность делегировать домен:
![image](https://user-images.githubusercontent.com/93075740/181727211-d843b10e-b7e4-486f-bf8a-255e2a81bfcc.png)
В поле DNS-серверы были прописаны DNS-серверы яндекса. 

Далее, в яндекс.облаке была создана зона dmitrii.website :
![image](https://user-images.githubusercontent.com/93075740/181727920-fece248e-55d9-4c61-9cb9-30409414a213.png)

![image](https://user-images.githubusercontent.com/93075740/181728214-fef5bab4-8e36-4155-9905-6ad2b355aecd.png)
Имя зоны (dmitrii-website-zone) далее использовалось в terraform манифесте.

### 2. Подготовить инфраструктуру с помощью Terraform на базе облачного провайдера YandexCloud.
#### Структура манифеста
Terraform манифест состоит из 2х файлов: 

version.tf:
```
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    bucket = "diplom"
    region = "ru-central1"
    key = "diplomstate/terrastate"
    access_key = "YCAJElj2DSFz2MUdbefGnYsqq"
    secret_key = "YCMDsWT44G39keFfW-nZ7PcDNWXSeO70E2bGWBzK"
    skip_region_validation = true
    skip_credentials_validation = true
  }
}
```
Указаны настройки провайдера Яндекс.облака, и настройки бэкэнда для сохранения состояния

Файл main.tf сосотоит из 5 частей:
1) Настройки провайдера Яндекс.облака:
```
provider "yandex" {
  cloud_id = "b1gdi5987arb0pnup4lj"
  folder_id = "b1gud7usbuekc5a56rtd"
  zone = "ru-central1-a"
}
```
2) Переменные locals, делятся на 7 блоков:

  2.1) Настройки домена:
  ```
  domain = "dmitrii.website"
  domain_name = "dmitrii-website-zone"
  ```
  2.2) Настройки виртуальных машин
  ```
    vm_maps = {
    "db01" = {
      stage = {
        cpu = 2
        mem = 2
        nat = true
      }
      prod = {
        cpu = 2
        mem = 2
        nat = true
      }
    }
    .
    .
    .
  }
  ```
  2.3) Список зон доступности и зона по-умолчанию
  ```
    zones = {
    "ru-central1-a" = "192.168.50.0/24"
    "ru-central1-b" = "192.168.51.0/24"
    "ru-central1-c" = "192.168.52.0/24"
  }
  default_zone = "ru-central1-a"
  ```
  2.4) Маппинг внешних имён на внутренние сервера:
  ```
    extnames_map = {
    "www" = "app"
    "gitlab" = "gitlab"
    "grafana" = "monitoring"
    "prometheus" = "monitoring"
    "alertmanager" = "monitoring"
  }
  ```
  2.5) Сетевые порты, на которых работают сервисы
  ```
    local_port_map = {
    "www" = 80
    "gitlab" = 80
    "grafana" = 3000
    "prometheus" = 9090
    "alertmanager" = 9093
  }
  ```
  2.6) Блок с переменным, паролями, токенами, названиями баз. Этот болк конвертируется в yaml и записывается в групповые переменные ansible
  ```
    vars = {
    stage = {
      "testcert" = false
      "mysql_replication_password" = "123456"
      "mysql_database_name" = "wordpress"
      "mysql_username" = "wordpress"
      "mysql_password" = "wordpress"
      "mysql_root_password" = "123456"
      "wordpress_web_root" = "/var/www/html"
      "wordpress_db_name" = "{{ mysql_database_name }}"
      "wordpress_db_username" = "{{ mysql_username }}"
      "wordpress_dp_password" = "{{ mysql_password }}"
      "git_root" = "Qwerty123"
      "private_token" = "sdfjeiw123qsxerty865"
      
    }
    prod = {
      "testcert" = false
      "mysql_replication_password" = "123456"
      "mysql_database_name" = "wordpress"
      "mysql_username" = "wordpress"
      "mysql_password" = "wordpress"
      "mysql_root_password" = "123456"
      "wordpress_web_root" = "/var/www/html"
      "wordpress_db_name" = "{{ mysql_database_name }}"
      "wordpress_db_username" = "{{ mysql_username }}"
      "wordpress_dp_password" = "{{ mysql_password }}"
      "git_root" = "Qwerty123"
      "private_token" = "sdfjeiw123qsxerty865"
    }
  }
  ```
  2.7) Сервер, внешний адрес которого будет использоваться для регистрации DNS-записей
  ```
    reverse_proxy = "nginx"
  ```
  
  3) Описание сетевых ресурсов. На основе переменных из п.2.3 (Local.zones) создаётся сеть и в ней - подсети
  ```
  resource "yandex_vpc_network" "network1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet1" {
  for_each = local.zones
  name = "subnet-${each.key}"
  zone = each.key
  network_id = yandex_vpc_network.network1.id
  v4_cidr_blocks = [each.value]
}
  ```
  4) Ищется образ ОС по имени ubuntu2004 (его нужно предварительно создать или взять публичный)
  ```
  data "yandex_compute_image" "cpuimage" {
  name = "ubuntu2004"
}
  ```
  5) Создаются виртуальные машины. Для создания используется образ, найденный на предыдущем шаге, маппинг local.vm_maps и одна из подсетей, созданная в п.3
  ```
  resource "yandex_compute_instance" "vms" {
  for_each = local.vm_maps
  name = "${each.key}"
  zone = local.default_zone
  
  resources {
    cores = each.value[terraform.workspace].cpu
    memory = each.value[terraform.workspace].mem
  }
  boot_disk {
    initialize_params {
      image_id = "${data.yandex_compute_image.cpuimage.id}"
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1[local.default_zone].id
    nat = each.value[terraform.workspace].nat
  }
  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
  ```
  6) Определяется идентификатор зоны dns по имени, указанному в переменной local.domain_name, и в этой зоне создаются записи для внешних url на основе маппинга  local.extnames_map. Так как записи динамически создаются и удаляются - TTL выставлен в 10 минут
  ```
  data "yandex_dns_zone" "dns_zone" {
  name = "${local.domain_name}"
}
resource "yandex_dns_recordset" "dns_records" {
  for_each = local.extnames_map
  zone_id = data.yandex_dns_zone.dns_zone.id
  name = "${each.key}"
  type = "A"
  ttl = 600
  data = ["${yandex_compute_instance.vms["${local.reverse_proxy}"].network_interface.0.nat_ip_address}"]
}
  ```
  7) создание inventory и group_vars для ansible
  ```
  resource "local_file" "hosts_cfg" {
  for_each = local.vm_maps
  content = "[${each.key}]\n${yandex_compute_instance.vms["${each.key}"].network_interface.0.ip_address} ansible_ssh_common_args='-o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@www.${local.domain}\"'\n"
  filename = "inventory/${each.key}"
}
resource "local_file" "var_cfg" {
  content = "domain_name: \"${local.domain}\"\nlocaladdress:\n%{ for vm in yandex_compute_instance.vms }  ${vm.name}: ${vm.network_interface.0.ip_address}\n%{ endfor ~}sites:\n%{ for key, value in local.extnames_map ~}- name: ${key}\n  address: \"{{ localaddress.${value} }}\"\n  port: ${lookup(local.local_port_map, "${key}")}\n%{ endfor ~}\n%{ for key, value in local.extnames_map ~}${key}_url: ${value}.${local.domain}\n%{ endfor ~}\n%{ for key, value in local.vars[terraform.workspace] ~}${key}: \"${value}\"\n%{ endfor ~}"
  filename = "inventory/group_vars/all/vars.yml"
}
  ```
#### Результаты terraform apply

### 3. Настроить внешний Reverse Proxy на основе Nginx и LetsEncrypt.
#### Описание роли
Для деплоя роли используется плейбук nginx.yml
```
---
- hosts: nginx
  name: Install Nginx revers proxy
  become: true
  roles:
    - nginx-proxy
```
В процессе деплоя выполняются следующие задачи:

- Устанавливаются пакеты nginx, certbot, python3-certbot-nginx
- Для каждого внешнего сайта генерируется конфиг с настройками какой сервер будет обслуживать запросы с этого адреса. Конфиги помещаются в папку /etc/nginx/sites-enabled, файлы названы по настроенному внешнему имени
- Для каждого сайта генерируется сертификат при помощи certbot
- Перезапускается nginx
#### результаты выполнения
### Репозиторий со всеми Terraform манифестами и готовность продемонстрировать создание всех ресурсов с нуля.

Терраформ манифесты в этом же репозитории (файлы version.tf и main.tf). Для использования нужно:
- настроенный яндекс CLI (утилита yc)
- установить переменную окружения YC_TOKEN. 
- в файле version.tf прописать настройки бэкенда для сохранения состояния
- в файле main.tf прописать идентификатор облака, папки и зону
- в облаке должен быть образ ubuntu 20.04 с именем ubuntu2004
- клауд DNS нужно делегировать внешнюю зону DNS (адреса будут автоматически создаваться и удаляться)
- в переменных locals указать доменную зону, название доменной зоны в облаке
- остальные переменные исправлять не обязательно

### Репозиторий со всеми Ansible ролями и готовность продемонстрировать установку всех сервисов с нуля.


Ansible-роли так же в этом репозитории в папке ansible. Для использования ролей созданы плейбуки

- gitlab - роль, которая устанавливает gitlab, gitlab-runner и настраивает сервер app, на который будет происходить деплой. В инвентаре должны быть группы gitlab, runner и app. 
Плейбук, использующий роль: gitlab.yml
- monitoring - роль, разворачивающая сервер мониторинга, и клиентов. В инвентаре должна быть группа monitoring.
- mysql-cluster - роль, разворачивающая кластер серверов mysql. В инвентаре должны быть группы db01 и db02
- nginx-proxy - роль, разворачивающая reverse-proxy, генерирует сертификаты
- wordpress - роль, разворачивающая wordpress.

Terraform при создании виртуальных машин генерирует инвентарь и group_vars. После успешного завершения работы Terraform можно сразу запускать плейбуки.

### Скриншоты веб-интерфейсов всех сервисов работающих по HTTPS на вашем доменном имени

- https://www.dmitrii.website (WordPress) 
![image](https://user-images.githubusercontent.com/93075740/181682032-7c8af482-a4b3-4577-8d3e-9c335a5d9e5f.png)
- https://gitlab.dmitrii.website (Gitlab)
![image](https://user-images.githubusercontent.com/93075740/181682214-ad66ab5e-a470-4bcd-9bcb-d5b179e3a3be.png)
- https://grafana.dmitrii.website (Grafana)
![image](https://user-images.githubusercontent.com/93075740/181682441-e3fb51f7-1c5b-44a1-99d5-793a9c86b2f6.png)
- https://prometheus.dmitrii.website (Prometheus)
![image](https://user-images.githubusercontent.com/93075740/181682722-20db6835-1e59-4cac-bc4c-be21eff19c47.png)
- https://alertmanager.dmitrii.website (Alert Manager)
![image](https://user-images.githubusercontent.com/93075740/181682881-473a811e-58b6-4f19-9890-16e9c122d1ad.png)

