## Шпаргалка по Docker

### Установка

### Состояние

```shell
docker version
```
или кратко
```shell
docker --version
```

Получить сводку по диску Docker
```shell
docker system df
```
Получить сводку по всем томам
```shell
docker volume ls
```
Получить сводку по всем томам
```shell
docker volume ls
```
```shell
# Список томов с размером
docker system df -v
```
Очистить все ненужные тома
```shell
docker volume prune -a
```
и для кэша всех сборок
```shell
docker builder prune
```

### Образы

Получить список всех образов
```shell
docker images
```
Удалить указанные образ
```shell
docker image rm имя_образа
```
или
```shell
docker rmi имя_образа
```
или удалить все образы
```shell
docker rmi $(docker images -a -q)
```

### Основные команды

### Контейнеры

Получить список всех контейнеров, не зависимо от их состояния
```shell
docker ps -a
```
Получить список контейнеров, из которых выполнен выход
```shell
docker ps -a -f status=exited
```

#### Удаление контейнеров

```shell
docker rm $(docker ps -a -f status=exited -q)
```

###

###

### Использование ресурсов

Показать подробную информацию об использовании дискового пространства:
```shell
docker system df -v
```

### DOCKER HUB

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
