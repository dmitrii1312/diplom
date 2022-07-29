## Диплом

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

