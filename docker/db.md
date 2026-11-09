## MongoDB (NoSQL)


1. Запуск **MongoDB**

в **Windows Powershell**
```shell
docker run -d `
  --name my-mongo `
  -p 27017:27017 `
  mongo:latest
```
![apk update](img/db/2026-03-31_10-41-39.png)

2. Подключиться через shell
```shell
docker exec -it my-mongo mongosh
```
![apk update](img/db/2026-03-31_10-42-18.png)

Некоторые команды для проверки

![apk update](img/db/2026-03-31_10-45-51.png)