#### Docker compose конетейнеры с PostgresSQL

**PostgreSQL** (часто — Postgres) — свободная объектно‑реляционная система управления базами данных (ORDBMS) с открытым исходным кодом.

Перед началом работы над этим проектом, проверье другие запущенные у вас **docker-compose** приложения:
```shell
docker compose ls
```
их лучше остановить, чтобы снизить риск возникновения конфликтов использования портов!

### 1. Структура проекта

```
postgres-docker-project/
├── data/           # Для хранения данных БД (volume)
├── scripts/        # SQL скрипты для инициализации
├── backups/        # Для бэкапов БД
└── docker-compose.yml  # Главный конфиг
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p postgres-docker-project/{data,scripts,backups} && touch postgres-docker-project/docker-compose.yml scripts/init.sql && cd postgres-docker-project
```


### 1. Файл `docker-compose.yml`

```yml
# Определение секции services - здесь перечисляются все контейнеры/сервисы
services:
  # Объявление сервиса с именем 'postgres'
  # Это логическое имя для обращения внутри docker-compose
  postgres:
    # Используемый Docker образ: postgres версии 15
    # Docker скачает его автоматически если нет локально
    image: postgres:15
    # Имя контейнера в Docker (будет видно в 'docker ps')
    # Без этого Docker сгенерирует случайное имя
    container_name: my-postgres
    # Переменные окружения для настройки PostgreSQL
    # Передаются в контейнер при запуске
    environment:
      # Создает базу данных с именем 'mydatabase' при первом запуске
      POSTGRES_DB: mydatabase
      # Создает пользователя 'myuser' с правами суперпользователя
      POSTGRES_USER: myuser
      # Устанавливает пароль 'mypassword' для пользователя myuser
      POSTGRES_PASSWORD: mypassword
    # Проброс портов между хостом и контейнером
    # Формат: "порт_хоста:порт_контейнера"
    ports:
      # Порт 5432 на хосте → порт 5432 в контейнере
      # Теперь можно подключиться к БД с хоста: localhost:5432
      - "5432:5432"
    # Монтирование томов (файлов/папок) между хостом и контейнером
    volumes:
      # Монтирует папку ./data на хосте в /var/lib/postgresql/data в контейнере
      # Это обеспечивает сохранность данных БД при перезапуске контейнера
      - ./data:/var/lib/postgresql/data
      # Монтирует SQL скрипт в специальную папку инициализации
      # PostgreSQL выполнит этот скрипт при первом запуске БД
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
      # Монтирует папку для бэкапов - удобно для экспорта/импорта данных
      - ./backups:/backups
    # Политика перезапуска контейнера при сбоях
    restart: unless-stopped
    # unless-stopped = перезапускать всегда, кроме случаев
    # когда контейнер был остановлен вручную (docker stop)
    # Настройка healthcheck - проверки здоровья контейнера
    # Docker будет автоматически проверять жив ли сервис
    healthcheck:
      # Команда для проверки: пробуем подключиться к PostgreSQL
      # pg_isready - утилита для проверки готовности PostgreSQL
      test: ["CMD-SHELL", "pg_isready -U myuser -d mydatabase"]
      # Интервал между проверками: 30 секунд
      interval: 30s
      # Таймаут ожидания ответа: 10 секунд
      timeout: 10s
      # Количество повторных попыток перед пометкой 'unhealthy'
      retries: 3
```

### 2. файл: `scripts/init.sql`

```sql
-- Создаем дополнительную базу данных
CREATE DATABASE app_db;

-- Создаем дополнительного пользователя
CREATE USER app_user WITH PASSWORD 'app_password';

-- Даем права
GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;

-- Создаем тестовую таблицу
\c mydatabase;

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Вставляем тестовые данные
INSERT INTO users (name, email) VALUES
('Иван Иванов', 'ivan@example.com'),
('Мария Петрова', 'maria@example.com')
ON CONFLICT (email) DO NOTHING;
```

### 3. Запуск и управление PostgreSQL в Docker

Находясь в каталоге проекта, выполнитеЖ
```shell
docker compose up -d
```
параметр `-d` отвечает за запуск контейнера в фоновом режиме

> если запустить контейнер без `-d` (интерактивный режим), то остановить его можно по **Ctrl+C** в терминале

проверяем его состояние (показать, что запущено именно этим compose-проектом):
```shell
docker compose ps
```
прочитаем логи запущенного контейнера с PostgreSQL
```shell
docker compose logs postgres
```
остановим контейнер с PostgreSQL (ОСТАНОВКА + УДАЛЕНИЕ контейнеров)
```shell
docker compose down
```
> Важно понимать, что данные БД не удалятся при остановке и удалении контейнера!
или
`docker compose stop` если нужно чтобы контейнер не удалился
> если выполнена остановка контейнера по stop, то запустить его снова можно командой `docker compose start`

снова проверим состояние запущенных контейнеров
```shell
docker ps -a
```
Показать конфигурацию текущего проекта:
```shell
docker compose config
```

> Для каждого нового Docker-контейнера лучше создавать отдельную папку, чтобы каждый проект был в своей папке. Это обеспечит наилучшую изоляцию проектов.

### 3. Управление БД в Docker-контейнере

Подключение к БД:
```shell
docker exec -it my-postgres psql -U myuser -d mydatabase
```
> чтобы выйти из подключенной БД, надо в командной строке БД выполнить EXIT

[Подключиться к БД с браузера localhost:5432](localhost:5432)

попробовал - пустая страница "Соединение с сайтом localhost было успешно установлено, но он не отправил ничего в ответ."

Останавливаем на время
```shell
docker compose stop
```
Запускаем обратно
```shell
docker compose start
```
или
```shell
docker compose up -d
```

#### 4. Удалить установленный Контейнер с PostgresSQL

Переходим в папку с проектом
```shell
cd ~/Docker/postgres-docker-project
```
Останавливаем и удаляем контейнеры, сети
```shell
docker compose down
```
Или с удалением volumes (данных БД)
```shell
docker compose down -v
```

> - Важно! ключ `-v` удаляет БД (**все данные будут потеряны**)!
> - Важно! При удалении контейнера образ сохраняется!

Проверяем что контейнеров нет
```shell
docker ps -a
```
Проверяем что volumes удалены
```shell
docker volume ls
```
Проверяем что нет сетей удаляемого образа
```shell
docker network ls
```

> Если `docker network ls` показывет сеть вашего docker compose, даже если он был удалён, то просто выполните `docker compose down`

Должны быть пустые списки или только системные элементы
- `docker ps -a`          # Не должно быть my-postgres
- `docker volume ls`      # Не должно быть postgres volumes
- `docker images`         # Образ postgres есть и его можно оставить (переиспользовать)

Дальнейшие действия зависят от вашего желания:

- **Вариант 1:** Использовать ту же конфигурацию

`docker compose up -d`

- **Вариант 2:** Создать, например, новый проект с улучшениями

`mkdir new-postgres-project`

`cd new-postgres-project`

Создать в нём новый `docker-compose.yml` с учетом полученного опыта

#### 5. Удаление образов (опционально)

Посмотреть все образы
```shell
docker images
```
Проверить, какие контейнеры используются
```shell
docker ps -a
```

- Удалить сначала неиспользуемые и остановленные контейнеры, например по **id**-контейнера

Только после этого можно удалять образы!

Удалить образ PostgreSQL
```shell
docker rmi postgres:15
```
Или удалить все неиспользуемые образы
```shell
docker image prune -a
```
Проверить результат удаления всех образов
```shell
docker images
```

Теперь можно запустить проект снова, с "чистого листа"!

- Загрузить и установить новый образ PostgreSQL из папки `postgres-docker-project`
`docker compose up -d`

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
