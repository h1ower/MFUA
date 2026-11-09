## Alt Linux в Docker

#### Использовать контейнер с Alt

##### Загрузить готовый образ Alt
```shell
docker pull alt:sisyphus
```
![alt text](img/altLinux/2026-03-31_12-07-29.png)

##### Запустить и использовать
```shell
docker run -ti --rm --name alt alt:sisyphus /bin/bash
```

#### Установить приложение Fastfetch в контейнере
```shell
apt-get update && apt-get install fastfetch
```

#### Запустить Fastfetch
```shell
fastfetch
```
![alt text](img/altLinux/2026-03-31_12-07-52.png)

##### Выйти из контейнера с Alt
```shell
exit
```

### Полезные ссылки

[alt Docker Official Image](https://hub.docker.com/_/alt/)

[Dockerfile](https://github.com/alt-cloud/docker-brew-alt/blob/p10/x86_64/Dockerfile)

[Docker Alt Linux Image](https://github.com/sibsau/docker-alt/blob/master/README.md)
