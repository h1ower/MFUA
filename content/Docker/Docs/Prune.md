`docker container prune` удаляет **только остановленные контейнеры**.

## 🔍 Что именно удаляет `docker container prune`

```bash
docker container prune
```

**УДАЛЯЕТ:**
- ✅ Все контейнеры со статусом `Exited` (завершенные)
- ✅ Все контейнеры со статусом `Created` (созданные, но не запущенные)

**НЕ УДАЛЯЕТ:**
- ❌ Запущенные контейнеры (со статусом `Up`)
- ❌ Приостановленные контейнеры (`paused`)

## 🧪 Демонстрация

Давайте проверим на практике:

```bash
# Создадим несколько контейнеров с разными статусами
docker run -d --name running-container nginx
docker run --name exited-container hello-world
docker create --name created-container ubuntu echo "test"

# Проверим статусы
docker ps -a
```
Вы увидите примерно:
```
CONTAINER ID   IMAGE         COMMAND                  STATUS                      NAMES
a1b2c3d4e5f6   nginx         "/docker-entrypoint.…"   Up 5 seconds                running-container
b2c3d4e5f6g7   hello-world   "/hello"                 Exited (0) 3 seconds ago    exited-container
c3d4e5f6g7h8   ubuntu        "echo test"              Created                     created-container
```

Теперь выполним:
```bash
docker container prune
```

**Результат:**
- ✅ `exited-container` — **УДАЛЕН**
- ✅ `created-container` — **УДАЛЕН**
- ❌ `running-container` — **ОСТАЛСЯ** работать

## 🛡️ Безопасность команды

Docker всегда запрашивает подтверждение:
```
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N]
```

Это защищает от случайного удаления.

## 📋 Полная таблица команд для удаления

| Команда | Что удаляет | Безопасность |
|---------|-------------|--------------|
| `docker container prune` | **Только остановленные** контейнеры | ✅ Безопасно |
| `docker rm <container>` | Конкретный контейнер (если остановлен) | ✅ Безопасно |
| `docker rm -f <container>` | Конкретный контейнер **даже запущенный** | ⚠️ Принудительно |
| `docker system prune` | Остановленные контейнеры + неиспользуемые образы + сети | ✅ С запросом подтверждения |
| `docker system prune -a` | **ВСЕ** неиспользуемые ресурсы (агрессивно) | ❌ Опасно |

## 🚨 Опасные команды (используйте осторожно!)

```bash
# Удаляет ВСЕ контейнеры (даже запущенные!)
docker rm -f $(docker ps -aq)

# Полная очистка системы (очень агрессивно)
docker system prune -a --volumes
```

## 🎯 Рекомендации по использованию

**Для регулярной очистки:**
```bash
# Безопасно удалить мусор
docker container prune

# Или с автоматическим подтверждением
docker container prune -f
```

**Для разработки:**
```bash
# Создавайте контейнеры с --rm для автоудаления
docker run --rm -it ubuntu /bin/bash

# Удаляйте конкретный контейнер
docker stop my-container && docker rm my-container
```

## 💡 Практический совет

Если вы только учитесь Docker, регулярно выполняйте:
```bash
# Посмотреть что есть
docker ps -a

# Безопасно почистить завершенные контейнеры
docker container prune

# Посмотреть результат
docker ps -a
```

Это сохранит вашу систему чистой и поможет лучше понимать жизненный цикл контейнеров! 🐳
> Если вы обраружили ошибку в этом тексте - сообщите пожалуйста автору!

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
