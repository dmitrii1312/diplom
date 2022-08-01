## Диплом
### 1. Зарегистрировать доменное имя (любое на ваш выбор в любой доменной зоне).
На nic.ru зарегистрировано доменное имя dmitrii.website. В личном кабинете на nic.ru появилась возможность делегировать домен:
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
  content = "%{ for key, value in local.vm_maps }[${key}]\n${yandex_compute_instance.vms["${key}"].network_interface.0.ip_address} ansible_ssh_common_args='-o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@${yandex_compute_instance.vms["${local.reverse_proxy}"].network_interface.0.nat_ip_address}\"'\n\n%{ endfor }"
  filename = "inventory/hosts"
}
resource "local_file" "var_cfg" {
  content = "domain_name: \"${local.domain}\"\nlocaladdress:\n%{ for vm in yandex_compute_instance.vms }  ${vm.name}: ${vm.network_interface.0.ip_address}\n%{ endfor ~}sites:\n%{ for key, value in local.extnames_map ~}- name: ${key}\n  address: \"{{ localaddress.${value} }}\"\n  port: ${lookup(local.local_port_map, "${key}")}\n%{ endfor ~}\n%{ for key, value in local.extnames_map ~}${key}_url: ${value}.${local.domain}\n%{ endfor ~}\n%{ for key, value in local.vars[terraform.workspace] ~}${key}: \"${value}\"\n%{ endfor ~}"
  filename = "inventory/group_vars/all/vars.yml"
}
  ```
#### Результаты terraform apply
Создалась сеть:
![image](https://user-images.githubusercontent.com/93075740/182112894-3e5c312c-6ee6-48c8-8947-36fcb00c62cc.png)

Создались подсети:
![image](https://user-images.githubusercontent.com/93075740/182113103-36758408-07c6-4b99-8ab6-8a1f582ab18c.png)

Создались виртуальные машины:
![image](https://user-images.githubusercontent.com/93075740/182113673-74f82d82-1532-4092-9e48-3ebedd8778a5.png)

Создались записи DNS:
![image](https://user-images.githubusercontent.com/93075740/182114043-400eea80-eae2-4462-9d84-bee1475b7437.png)

Создались файлы inventory/hosts и inventory/group_vars/all/vars.yml
```
$ cat inventory/hosts
[app]
192.168.50.31 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'

[db01]
192.168.50.21 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'

[db02]
192.168.50.12 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'

[gitlab]
192.168.50.24 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'

[monitoring]
192.168.50.11 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'

[nginx]
192.168.50.19 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'

[runner]
192.168.50.3 ansible_ssh_common_args='-o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p -q ubuntu@84.201.128.57"'
```
```
$ cat inventory/group_vars/all/vars.yml
domain_name: "dmitrii.website"
localaddress:
  app: 192.168.50.31
  db01: 192.168.50.21
  db02: 192.168.50.12
  gitlab: 192.168.50.24
  monitoring: 192.168.50.11
  nginx: 192.168.50.19
  runner: 192.168.50.3
sites:
- name: alertmanager
  address: "{{ localaddress.monitoring }}"
  port: 9093
- name: gitlab
  address: "{{ localaddress.gitlab }}"
  port: 80
- name: grafana
  address: "{{ localaddress.monitoring }}"
  port: 3000
- name: prometheus
  address: "{{ localaddress.monitoring }}"
  port: 9090
- name: www
  address: "{{ localaddress.app }}"
  port: 80
alertmanager_url: monitoring.dmitrii.website
gitlab_url: gitlab.dmitrii.website
grafana_url: monitoring.dmitrii.website
prometheus_url: monitoring.dmitrii.website
www_url: app.dmitrii.website
git_root: "Qwerty123"
mysql_database_name: "wordpress"
mysql_password: "wordpress"
mysql_replication_password: "123456"
mysql_root_password: "123456"
mysql_username: "wordpress"
private_token: "sdfjeiw123qsxerty865"
testcert: "false"
wordpress_db_name: "{{ mysql_database_name }}"
wordpress_db_username: "{{ mysql_username }}"
wordpress_dp_password: "{{ mysql_password }}"
wordpress_web_root: "/var/www/html"
```

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

#### Результаты выполнения ansible-playbook nginx.yml
После выполнения плейбука создались конфиги в папке /etc/nginx/sites-enabled вида:
```
$ cat /etc/nginx/sites-enabled/www
server {
    server_name www.dmitrii.website;
    client_max_body_size 1G;
    location / {
        proxy_redirect          off;

        proxy_buffering off;

        proxy_set_header    Host                $http_host_with_default;
        proxy_set_header    X-Real-IP           $remote_addr;
        proxy_set_header    X-Forwarded-For     $proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto   $scheme;
        proxy_pass http://192.168.50.31/;

    }


    listen [::]:443 ssl; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/www.dmitrii.website/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/www.dmitrii.website/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = www.dmitrii.website) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    listen [::]:80;
    server_name www.dmitrii.website;
    return 404; # managed by Certbot
```
так же создались сертификаты для всех проксируемых сайтов alertmanager.dmitrii.website, gitlab.dmitrii.website, grafana.dmitrii.website, prometheus.dmitrii.website и www.dmitrii.website

Скрин сайта www.dmitrii.website
![image](https://user-images.githubusercontent.com/93075740/182118920-49707986-44f2-4ce6-91e9-fd3ac889f7c0.png)

### 4. Настроить кластер MySQL.
#### Описание роли
Роль разворачивается на 2х хостах - db01 и db02. При этом db01 - master, db02 - slave. Внутри роли таски распределяются в зависимости о того, к какой группе принадлежит хост (группа db01 и db02). В процессе деплоя выполняются следующие задачи:
- На хостах устанавливаются пакеты mysql-server, mysql-client, python3-pymysql
- на оба хоста копируется серверный конфиг mysqld.cnf в папку /etc/mysql/mysql.conf.d/, в конфиге случайным образом генерируется параметр server-id
- сервер mysql перезапускается с новым конфигом
- Пользователю root присваивается пароль, и ограничивается доступ только с локального хоста
- Создаётся пользователь репликации с правами доступа с адресов серверов БД
- Считывается текущее состояние на db02 (slave)
- Считывается текущее состояние на db01 (master)
- в файл /tmp/master.File хоста, на котором выполняется ansible, сохраняется текущий файл логов db01
- в файл /tmp/master.Position сохраняется текущая позиция db01
- на db02 настраивается db01 мастером репликации
- на db02 запускается репликация
- создаётся база wordpress и пользователь wordpress c паролем wordpress

#### Результат выполнение ansible-playbook mysql.yml
Запущена репликация:
```
# mysql -p
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 24
Server version: 8.0.30-0ubuntu0.20.04.2 (Ubuntu)

Copyright (c) 2000, 2022, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> SHOW SLAVE STATUS\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: 192.168.50.21
                  Master_User: replication
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: binlog.000004
          Read_Master_Log_Pos: 3985
               Relay_Log_File: fhma5coq7vnekql4jdal-relay-bin.000002
                Relay_Log_Pos: 1306
        Relay_Master_Log_File: binlog.000004
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 3985
              Relay_Log_Space: 1531
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 9029
                  Master_UUID: a1fcaee0-117e-11ed-8c8b-d00d163a7660
             Master_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set:
                Auto_Position: 0
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:
       Master_public_key_path:
        Get_master_public_key: 0
            Network_Namespace:
1 row in set, 1 warning (0.00 sec)
```
Созданы необходимые пользователи:
```
mysql> use mysql;
Database changed
mysql> select user,host from user;
+------------------+---------------+
| user             | host          |
+------------------+---------------+
| replication      | 127.0.0.1     |
| root             | 127.0.0.1     |
| replication      | 192.168.50.12 |
| replication      | 192.168.50.21 |
| wordpress        | 192.168.50.31 |
| debian-sys-maint | localhost     |
| mysql.infoschema | localhost     |
| mysql.session    | localhost     |
| mysql.sys        | localhost     |
| replication      | localhost     |
| root             | localhost     |
+------------------+---------------+
11 rows in set (0.00 sec)
```
Создана база wordpress
```
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| wordpress          |
+--------------------+
5 rows in set (0.00 sec)
```

### 5. Установить WordPress
#### Описание роли
Роль разворачивается на сервере app. Для работы сервиса предварительно нужно развернуть кластер MySQL из предыдущего пункта
В процессе деплоя выполняются следующие задачи:
- Установка пакетов apache2 и php
- в папку /var/www/html распаковывается архив wordpress свежей версии
- копируется файл конфигурации wp-config.php, с настройками доступа к базе, внешним url, и логинами-паролями
- Удаляется файл /var/www/html/index.html который идёт с пакетом apache2. После этого по пути / будет отдаваться файл index.php
- Проверяется, что apache2 запущен

#### Результаты выполнения ansible-playbook wordpress.yml
Скрин сайта www.dmitrii.website
![image](https://user-images.githubusercontent.com/93075740/182125874-06e4fc73-f631-406e-8f5d-b7840c022f4c.png)
в конфиге установлены параметры:
```
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wordpress' );
define( 'DB_PASSWORD', 'wordpress' );
define( 'DB_HOST', '192.168.50.21' );
define( 'WP_HOME', 'https://www.dmitrii.website' );
define( 'WP_SITEURL', 'https://www.dmitrii.website' );
```

### 6. Развернуть Gitlab CE и Gitlab Runner.
#### Описание роли
Роль задействует 4 хоста: gitlab, runner, app, localhost. Первые три хоста распределены по группам с такими же именами. Таски выполняются в соответствии с группой хоста. В процессе деплоя выполняются следующие задачи:
- На хосте gitlab
- - Установка пакетов curl, ca-certificates, tzdata, perl
- - Скачивание и запуск скрипта добавления репозитория gitlab-ce (https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh) в папку /tmp
- - Создаётся папка /etc/gitlab и в неё копируется файл gitlab.rb, если таск вызвал изменения, то оповещается handler по реконфигурации gitlab
- - Устанавливается пакет gitlab-ce, так же как и предыдущий таск, в случае изменения - оповещается handler реконфигурации gitlab
- - Если handler реконфигурации оповещён, то на этом шаге выполняется реконфигурация gitlab
- - Следующие 2 таска регистрируют токен для пользователя root (на gitlab копируется скрипт сброса токена и выполняется сброс). Сам токен указывается в переменных или берётся дефолтный, указанный в роли.
- На localhost
- - Через RestAPI gitlab осуществляется сброс токена регистрации gitlab-runner
- - Токен отображается в консоли и записывается в файл /tmp/register-token
- На runner
- - Скачивается и устанавливается пакет установки runner (gitlab-runner_amd64.deb)
- - скачивается скрипт регистрации runner, в случае если таск вызвал изменения, то оповещается handler регистрации runner
- - Следующие 4 таска - это установки docker на runner
- На localhost
- - Через RestAPI создаётся новый проект wordpress
- - репозиторий этого проекта клонируется в папку /tmp/wordpress
- - В URL репозитория добавляется токен
- - В репозиторий добавляется файл CI/CD (.gitlab-ci.yml)
- - Чтобы не портить текущую установку Wordpress, в папку репозитория распаковывается свежая версия Wordpress
- - Проверяется состояние репозитория, и если есть незакоммиченные изменения, оповещается handler git add/commit/push
- - вызываются все накопившиеся hadler (регистрация runner и git add/commit/push)
- - Создаётся ключевая пара ssh для доступа runner к app (/tmp/app-key и /tmp/app-key.pub
- - Получается идентификатор пользователя root
- - и ко всем проектам этого пользователя добавляется переменная SSH_PRIVATE_KEY, содержащая закрытый ключ /tmp/app-key
- На app
- - Публичный ключ для подключения под root пишется в /root/.ssh/authorized_keys
- - В конфигурацию sshd_config добавляется разрешения подключаться пользователем root
- - Выполняется перезапуск sshd

#### Результаты выполнения ansible-playbook gitlab.yml
Создался токен регистрации runner:
```
$ cat /tmp/register-token
p6bP_zfcpzzj2oyVsVnN
```
Создалсья проект wordpress:
![image](https://user-images.githubusercontent.com/93075740/182129999-467daf52-a37e-4cd8-bd24-ce79710d7646.png)
В репозитории файлы wordpress и .gitlab-ci.yml
![image](https://user-images.githubusercontent.com/93075740/182130292-1e8c8339-b533-46e2-8856-55c2eaaf08cd.png)
В проект добавлена переменная SSH_PRIVATE_KEY
![image](https://user-images.githubusercontent.com/93075740/182131141-f674a66f-7002-4a13-8ebd-5a115368f1fa.png)
Workflow CI/CD отработал успешно:
![image](https://user-images.githubusercontent.com/93075740/182131451-a6b9c7b3-c8a1-4078-95e1-f582aff3198d.png)
Runner зарегистрирован в gitlab
![image](https://user-images.githubusercontent.com/93075740/182131935-3e9b3dd8-bfb3-4b34-b42d-ebc3fd1ee189.png)


### 7. Настроить CI/CD для автоматического развёртывания приложения.
При разворачивании gitlab создаётся репозиторий с файлом .gitlab-ci.yml
```
stages:
  - deploy

deploy_production:
  stage: deploy
  script:
    - 'which ssh-agent || ( apk update && apk add openssh-client rsync )'
    - eval $(ssh-agent -s)
    - ssh-add <(echo "$SSH_PRIVATE_KEY")
    - mkdir -p ~/.ssh
    - '[[ -f /.dockerenv ]] && echo -e "Host *\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config'
    - rsync -a --delete --exclude .git --exclude wp-config.php --exclude wp-settings.php /builds/root/wordpress/ root@{{ localaddress.app }}:/var/www/html
```
После создания контейнера, в него в папку /builds/root/wordpress клонируется репозиторий, и эта папка синхронизируется с папкой на сервере app.

#### Результат выполнения

### 8. Настроить мониторинг инфраструктуры с помощью стека: Prometheus, Alert Manager и Grafana
#### Описание роли
Роль выполняетсе на всех хостах из инвентаря. Таски выполняются на группе monitoring и остальных хостах. В процессе деплоя выполняются следующие задачи:
- На хосте monitoring устанавливается docker и docker-compose
- Синхронизируется папка stack с манифестом для docker-compose и конфигами сервисов
- Составляется список адресов клиентских машин, который будет использован для настройки job node_exporter Prometheus'а
- Далее копируется конфиг prometheus.yml
- Скачиваются образы и из них запускаются контейнеры prometheus
- На клиентские машины устанавливается node_exporter в виде сервиса
- Сервис node_exporter запускается и включается его автозапуск

#### Результат выполнения

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

