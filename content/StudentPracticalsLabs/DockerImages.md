# Задания по готовым Docker-образам

> - **Никогда в разработке не используйте русские имена файлов и каталогов!**
> - **Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!**

---

### Задачи

Основные этапы выполнения задач на примере веб-сервера **Nginx**:
- В редакторе кода **VS Code** выполняете по очереди все ниже приведённые задания и пушите их на свой **Github** или **Gitflic**
- Все задания выполняются в корне текущего каталого пользователя, например `/home/user/`. Для получения текущего пути выполните `pwd`, для быстрого перехода в корневой каталог текущего пользователя выполните в командной строке `cd ~`
- Делаете скриншоты каждого этапа и запущенного приложения, сохраняете их в папку вашего основного репозитория
- Оформить в `README.md` все этапы по [примеру с Nginx](/content/Docker/Dockerfile/my-site.md), со скриншотами в документе;
- Прислать преподавателю прямую ссылку на оформленную страницу `README.md` в своём удалённом репозитории с выполненным заданием, потом со всеми выполненными заданиями
- После укаждого успешно выполненного задания лучше удалять его контейнер, образ и каталог, чтобы следующее задание начинать с **"чистого листа"**
- Чтобы в командной строке **VS Code** быстро перейти в домашний каталог текущего пользователя, выполните `cd ~`

---

## 🧱 Категория 1. Базовые команды и жизненный цикл контейнера

### 1. **Hello World с исследованием**
```bash
docker run hello-world
```
**Задания:**
- Найти образ `hello-world` в `docker images`
- Посмотреть `docker ps -a` — ответить на вопрос: почему контейнера нет в `docker ps`?
- Найти его в `docker ps -a`, удалить через `docker rm`
- Повторить запуск с флагом `--rm` — ответить на вопрос: в чём разница?

### 2. **Alpine — самый маленький Linux**
```bash
docker run -it alpine sh
```
**Задания:**
- Сравнить размер `alpine` и `ubuntu` через `docker images`
- Внутри контейнера выполнить `cat /etc/os-release`
- Выйти через `exit` и снова зайти — что изменилось?
- Запустить `docker run alpine uname -a` одной командой

### 3. **BusyBox — «швейцарский нож» Linux**
```bash
docker run -it busybox sh
```
**Задания:**
- Найти 5 отличий от Alpine
- Выполнить `wget` какого-нибудь файла внутри контейнера
- Проверить размер образа (`docker images busybox`)

### 4. **Debian и Ubuntu — сравнение**
```bash
docker run -it debian:bookworm-slim bash
docker run -it ubuntu:24.04 bash
```
**Задания:**
- Сравнить `cat /etc/debian_version` в обоих
- Установить `curl` в каждом (`apt update && apt install -y curl`)
- Выйти и снова зайти — установился ли `curl`? ответить на вопрос: Почему?

---

## 💾 Категория 2. Тома и сохранение данных

### 5. **Первый volume — сохраняем файл**
```bash
docker run -it --name vol-test -v my-vol:/data alpine sh
```
**Задания:**
- Внутри контейнера: `echo "Hello" > /data/test.txt`
- Выйти, удалить контейнер (`docker rm vol-test`)
- Создать новый контейнер с тем же volume и проверить — ответить на вопрос: файл на месте?
- Найти volume через `docker volume ls`, посмотреть `docker volume inspect my-vol`

### 6. **Bind mount — папка с хоста**
```bash
mkdir ~/docker-bind && echo "from host" > ~/docker-bind/host.txt
docker run -it -v ~/docker-bind:/data alpine sh
```
**Задания:**
- Внутри контейнера: `cat /data/host.txt`
- Создать файл из контейнера: `echo "from container" > /data/container.txt`
- Выйти, проверить на хосте: `ls ~/docker-bind/`
- В чём разница между `my-vol` и `~/docker-bind`?

### 7. **Volume vs Bind mount — сравнение**
**Задания:**
- Сделать одно и то же с двумя типами монтирования
- Найти оба через `docker volume ls` (найти можно только один — почему?)
- Записать вывод в таблицу сравнения

### 8. **Данные переживают удаление контейнера**
```bash
docker run -d --name pg1 -e POSTGRES_PASSWORD=pass -v pgdata:/var/lib/postgresql/data postgres:16-alpine
```
**Задания:**
- Подождать 10 секунд, зайти в `psql`, создать таблицу `test`
- Удалить контейнер (`docker rm -f pg1`)
- Запустить новый контейнер с тем же volume
- Проверить — таблица на месте?
- **Контрольный вопрос:** что будет, если запустить без `-v`?

---

## 🌐 Категория 3. Сети и взаимодействие контейнеров

### 9. **Первый пользовательский bridge**
```bash
docker network create my-net
docker network ls
```
**Задания:**
- Запустить два контейнера Alpine в этой сети:
  ```bash
  docker run -d --name a1 --network my-net alpine sleep 3600
  docker run -d --name a2 --network my-net alpine sleep 3600
  ```
- Из `a1` пингануть `a2` по имени: `docker exec a1 ping -c 2 a2`
- Работает ли ping по IP?

### 10. **Два контейнера не видят друг друга в default bridge**
**Задания:**
- Запустить два контейнера **без** `--network`:
  ```bash
  docker run -d --name b1 alpine sleep 3600
  docker run -d --name b2 alpine sleep 3600
  ```
- Попробовать `docker exec b1 ping b2` — почему не работает?
- В default bridge связь по имени **не работает** — только по IP
- Найти IP через `docker inspect b1` и пингануть

### 11. **Nginx + curl — клиент-сервер**
```bash
docker network create web-net
docker run -d --name web --network web-net nginx:alpine
docker run -it --rm --network web-net alpine sh
```
**Задания:**
- Внутри Alpine: `wget -O- http://web`
- Видите «Welcome to nginx»?
- Выйти, остановить `web`, повторить — ответить на вопрос: что изменилось?

### 12. **PostgreSQL + Adminer — веб-клиент**
```bash
docker network create db-net
docker run -d --name pg --network db-net -e POSTGRES_PASSWORD=secret postgres:16-alpine
docker run -d --name adminer --network db-net -p 8081:8080 adminer
```
**Задания:**
- Открыть http://localhost:8081
- Войти: сервер `pg`, пользователь `postgres`, пароль `secret`
- Создать таблицу через веб-интерфейс
- **Контрольный вопрос:** почему в поле «сервер» пишем `pg`, а не `localhost`?

### 13. **Redis + клиент**
```bash
docker network create redis-net
docker run -d --name redis --network redis-net redis:alpine
docker run -it --rm --network redis-net redis:alpine redis-cli -h redis
```
**Задания:**
- Внутри CLI: `SET mykey "hello"` → `GET mykey`
- `KEYS *`
- Выйти и зайти заново — данные на месте? (да, пока контейнер `redis` жив)
- Удалить контейнер `redis` — ответить на вопрос: что произошло с данными?

---

## 🔧 Категория 4. Переменные окружения и конфигурация

### 14. **MySQL с переменными окружения**
```bash
docker run -d --name mysql1 \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=testdb \
  -e MYSQL_USER=user \
  -e MYSQL_PASSWORD=pass \
  mysql:8
```
**Задания:**
- Зайти внутрь: `docker exec -it mysql1 mysql -uuser -ppass`
- Проверить `SHOW DATABASES;` — есть ли `testdb`?
- Что было бы, если не указать `MYSQL_ROOT_PASSWORD`?

### 15. **Nginx с кастомной страницей через env**
```bash
docker run -d --name env-nginx -p 8081:80 -e NGINX_HOST=example.com nginx:alpine
```
**Задания:**
- Проверить переменные внутри: `docker exec env-nginx env`
- Понять, какие переменные образ **сам** использует

### 16. **Сравнение `-e` и `--env-file`**
**Задания:**
- Создать файл `my.env`:
  ```
  MY_VAR1=hello
  MY_VAR2=world
  ```
- Запустить: `docker run --rm --env-file my.env alpine env`
- Сравнить с `-e MY_VAR1=hello`
- **Контрольный вопрос:** когда `--env-file` удобнее?

---

## 📋 Категория 5. Логи и отладка

### 17. **Логи nginx**
```bash
docker run -d --name log-nginx -p 8081:80 nginx:alpine
```
**Задания:**
- Сделать несколько запросов: `curl localhost:8081`
- Посмотреть логи: `docker logs log-nginx`
- Найти свой IP в логах
- Смотреть логи в реальном времени: `docker logs -f log-nginx` (и сделать ещё запрос)
- Выйти: `Ctrl+C`

### 18. **Логи с таймстампами**
```bash
docker run -d --name ts-nginx nginx:alpine
```
**Задания:**
- `docker logs ts-nginx` — увидеть формат
- `docker logs --timestamps ts-nginx` — в чём разница?
- `docker logs --tail 5 ts-nginx` — последние 5 строк
- `docker logs --since 1m ts-nginx` — за последнюю минуту

### 19. **Healthcheck в действии**
```bash
docker run -d --name hc-nginx \
  --health-cmd "wget -q -O- http://localhost || exit 1" \
  --health-interval 5s \
  --health-retries 3 \
  nginx:alpine
```
**Задания:**
- Подождать 15 секунд
- `docker ps` — что в колонке STATUS?
- `docker inspect hc-nginx --format '{{json .State.Health}}'`
- Что будет, если сделать healthcheck неправильным?

### 20. **`docker stats` — мониторинг ресурсов**
**Задания:**
- Запустить несколько контейнеров: nginx, redis, alpine sleep
- Открыть `docker stats` в отдельном терминале
- В другом терминале нагрузить nginx запросами:
  ```bash
  for i in {1..1000}; do curl -s localhost:8080 > /dev/null; done
  ```
- Наблюдать за CPU/RAM в `docker stats`
- Выйти: `Ctrl+C`

---

## 🐳 Категория 6. Интересные и необычные образы

### 21. **`cowsay` — говорящая корова**
```bash
docker run --rm docker/whalesay cowsay "Hello Docker"
```
**Задания:**
- Узнать, что за образ `docker/whalesay`
- Сравнить с `cowsay` (можно запустить через `alpine` + `apk add cowsay`)
- Придумать своё сообщение

### 22. **`figlet` — ASCII-арт**
```bash
docker run --rm python:3-alpine sh -c "pip install pyfiglet -q && pyfiglet 'DOCKER'"
```
**Задания:**
- Получить свой текст в ASCII-арте
- Найти готовый образ с `figlet` на Docker Hub
- **Контрольный вопрос:** почему не всегда есть готовый образ «под всё»?

### 23. **`httpd` — статический сайт за 10 секунд**
```bash
mkdir ~/my-site && echo "<h1>Hello</h1>" > ~/my-site/index.html
docker run -d --name my-httpd -p 8080:80 -v ~/my-site:/usr/local/apache2/htdocs httpd:alpine
```
**Задания:**
- Открыть http://localhost:8080
- Изменить файл на хосте — обновить страницу
- **Контрольный вопрос:** почему изменения видны **без** перезапуска?

### 24. **`whoami` — самый маленький образ**
```bash
docker run --rm containous/whoami
```
**Задания:**
- Понять, что образ делает
- Запустить с `-p 8080:80` и посмотреть через `curl localhost:8080`
- Сравнить размер с `nginx:alpine`

### 25. **`alpine` + `curl` + `jq` — ручной API-клиент**
```bash
docker run --rm alpine sh -c "apk add --no-cache curl jq -q && curl -s https://api.github.com/repos/docker/docker-ce | jq .stargazers_count"
```
**Задания:**
- Получить количество звёзд любого репозитория
- Понять, что делает каждый пайп
- **Контрольный вопрос:** почему `apk add` с `--no-cache`?

---

## 🎓 Бонус: Задания на «подумать»

### 26. **Почему контейнер останавливается сам?**
```bash
docker run alpine echo "bye"
docker run alpine sleep 5
docker run -d alpine sleep 100
```
**Вопросы:**
- Почему первый контейнер не виден в `docker ps`?
- Какой сигнал посылается контейнеру при `docker stop`?
- Что делает `docker run -d`?

### 27. **Разница `run`, `exec`, `attach`**
```bash
docker run -d --name demo alpine sleep 3600
docker exec -it demo sh
docker attach demo    # не работает — нет главного процесса
```
**Задания:**
- Понять, почему `attach` «зависает» на `sleep`
- Попробовать `attach` на контейнере с интерактивным процессом
- **Контрольный вопрос:** когда использовать `exec`, а когда `attach`?

### 28. **Сколько места занимают образы**
```bash
docker system df
docker system df -v
```
**Задания:**
- Найти 3 самых больших образа
- Понять разницу между SIZE и RECLAIMABLE
- Очистить неиспользуемое: `docker image prune`

### 29. **Порты внутри vs снаружи**
```bash
docker run -d -p 8080:80 nginx:alpine
docker port <container>
```
**Задания:**
- Понять, что значит `8080:80`
- Запустить 3 nginx на разных портах:
  ```bash
  docker run -d -p 8081:80 nginx
  docker run -d -p 8082:80 nginx
  docker run -d -p 8083:80 nginx
  ```
- Открыть все три в браузере
- **Контрольный вопрос:** почему все три используют порт 80 **внутри**, но разные снаружи?

### 30. **`docker inspect` — паспорт контейнера**
```bash
docker run -d --name insp nginx:alpine
docker inspect insp
```
**Задания:**
- Найти в выводе:
  - IP-адрес
  - Путь к логам
  - Переменные окружения
  - Монтирования
- Отфильтровать через `--format`:
  ```bash
  docker inspect insp --format '{{.NetworkSettings.IPAddress}}'
  ```

---

## 🎁 Что покрывают эти задания?

| Тема | Задания |
|------|---------|
| **Основы и жизненный цикл** | 1–4, 26, 27 |
| **Тома и данные** | 5–8 |
| **Сети** | 9–13 |
| **Переменные окружения** | 14–16 |
| **Логи и отладка** | 17–20 |
| **Полезные образы** | 21–25 |
| **Инспекция и понимание** | 28–30 |

---

## 💡 Рекомендация по структуре курса

Если расположить по возрастанию сложности:

```
Неделя 1: 1, 2, 3, 4, 26           (основы)
Неделя 2: 5, 6, 7, 17, 18         (данные и логи)
Неделя 3: 9, 10, 11, 14, 29       (сети и env)
Неделя 4: 8, 12, 13, 19, 20       (реальные сервисы)
Неделя 5: 21, 22, 23, 24, 25      (интересное)
Неделя 6: 15, 16, 28, 30, 27      (закрепление)
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!