## **🎯 Что такое Portainer?**

**Portainer** — open-source веб-интерфейс для управления Docker, Docker Swarm и Kubernetes. Это как "панель управления" для Docker, где можно делать всё через браузер вместо командной строки.

## **🚀 Базовая установка**

### **1. Минимальная команда (ваш пример):**
```bash
docker run -d \
  --name portainer \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  portainer/portainer
```

### **2. Рекомендуемая команда (с томами для данных):**
```bash
docker run -d \
  --name portainer \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  --restart unless-stopped \
  portainer/portainer-ce:latest
```

## **📦 Что делает каждая часть команды:**

| Часть команды | Что делает | Зачем нужно |
|--------------|------------|-------------|
| `docker run -d` | Запускает контейнер в фоне | Чтобы не занимать терминал |
| `--name portainer` | Даёт имя контейнеру | Для удобного управления |
| `-p 9000:9000` | Пробрасывает порт 9000 | Веб-интерфейс на порту 9000 |
| `-p 9443:9443` | Пробрасывает порт 9443 | HTTPS доступ |
| `-v /var/run/docker.sock:/var/run/docker.sock` | Монтирует Docker сокет | Даёт доступ к Docker API |
| `-v portainer_data:/data` | Создаёт том для данных | Сохраняет настройки между перезапусками |
| `--restart unless-stopped` | Автоперезапуск | Поднимается после перезагрузки |
| `portainer/portainer-ce:latest` | Использует образ Portainer Community Edition | Бесплатная версия |

## **🌐 Первый запуск и настройка**

1. **Откройте в браузере:** `http://localhost:9000` (или `https://localhost:9443`)
2. **Создайте пароль администратора** (минимум 8 символов)
3. **Выберите, к чему подключиться:**
   - **Local** - локальный Docker демон (обычный выбор)
   - **Remote** - удалённый Docker демон
4. **Нажмите "Connect"**

## **🎛️ Основные возможности Portainer**

### **📋 Dashboard (Главная панель):**
- Обзор всех контейнеров, образов, сетей, томов
- Использование ресурсов (CPU, RAM, диски)
- Быстрый доступ к логам, консоли

### **🐳 Контейнеры:**
```
Что можно делать:
✓ Создавать/удалять/останавливать/перезапускать
✓ Просматривать логи в реальном времени
✓ Открывать терминал внутри контейнера
✓ Копировать файлы в/из контейнера
✓ Просматривать статистику использования ресурсов
✓ Экспортировать/импортировать контейнеры
```

### **🖼️ Образы (Images):**
- Просмотр всех образов
- Pull новых образов из Docker Hub
- Удаление образов
- Сборка образов из Dockerfile

### **🔗 Сети (Networks):**
- Создание пользовательских сетей
- Просмотр сетевой топологии
- Подключение/отключение контейнеров к сетям

### **💾 Тома (Volumes):**
- Создание и удаление томов
- Просмотр содержимого томов
- Резервное копирование томов

### **📝 Стеки (Stacks):**
- Развёртывание Docker Compose файлов
- Управление несколькими сервисами
- Просмотр логов и статуса стека

## **🔧 Практические примеры через Portainer**

### **Пример 1: Создание контейнера через GUI**
1. Зайдите в **Containers** → **Add container**
2. Заполните:
   - **Name**: `my-nginx`
   - **Image**: `nginx:alpine`
   - **Port mapping**: `8080:80`
3. Нажмите **Deploy the container**
4. Откройте `http://localhost:8080`

### **Пример 2: Запуск Docker Compose через Stacks**
1. **Stacks** → **Add stack**
2. **Name**: `wordpress`
3. **Web editor** → Вставьте:
```yaml
version: '3.8'
services:
  db:
    image: mysql:5.7
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: wordpress
    volumes:
      - db_data:/var/lib/mysql

  wordpress:
    image: wordpress:latest
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: rootpassword
volumes:
  db_data:
```
4. **Deploy the stack**

### **Пример 3: Мониторинг контейнера**
1. **Containers** → Выберите контейнер
2. Видите вкладки:
   - **Logs** - логи в реальном времени
   - **Console** - терминал внутри контейнера
   - **Stats** - использование CPU, памяти, сети
   - **Inspect** - полная информация о контейнере

## **⚙️ Настройки Portainer**

### **1. Безопасность (HTTPS):**
```bash
# Создайте SSL сертификаты
mkdir -p ~/portainer/certs
openssl genrsa -out ~/portainer/certs/portainer.key 2048
openssl req -new -x509 -sha256 -key ~/portainer/certs/portainer.key -out ~/portainer/certs/portainer.crt -days 3650

# Запуск с SSL
docker run -d \
  --name portainer \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/portainer/certs:/certs \
  -v portainer_data:/data \
  -e SSL_CERT_FILE="/certs/portainer.crt" \
  -e SSL_KEY_FILE="/certs/portainer.key" \
  portainer/portainer-ce
```

### **2. Подключение к удалённому Docker:**
```bash
# На удалённом сервере настройте Docker для удалённого доступа
# /etc/docker/daemon.json:
{
  "hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]
}

# В Portainer при установке выберите "Remote" и укажите:
# Endpoint URL: tcp://IP_СЕРВЕРА:2375
```

### **3. Авторизация и пользователи:**
- Создавайте команды (teams) и назначайте права
- Ограничивайте доступ по ресурсам
- Настройте LDAP/AD интеграцию

## **📊 Мониторинг в Portainer**

### **Dashboard показывает:**
- Количество контейнеров (работающих/остановленных)
- Использование CPU и памяти
- Сетевой трафик
- Активность дисков

### **Дополнительные возможности:**
```bash
# Установка агента для кластера
docker run -d \
  -p 9001:9001 \
  --name portainer_agent \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /var/lib/docker/volumes:/var/lib/docker/volumes \
  portainer/agent:latest
```

## **🔄 Управление через Portainer vs Командная строка**

| Действие | Portainer | Командная строка |
|----------|-----------|------------------|
| **Просмотр контейнеров** | Таблица с поиском и фильтрами | `docker ps` |
| **Логи** | Веб-интерфейс с паузами, поиском | `docker logs` |
| **Терминал** | Встроенный в браузер | `docker exec -it` |
| **Файлы** | Файловый менеджер | `docker cp` |
| **Статистика** | Графики в реальном времени | `docker stats` |
| **Сети** | Визуальная схема подключений | `docker network` |

## **🔐 Безопасность**

### **Важные моменты безопасности:**
1. **Пароль** — сразу измените пароль по умолчанию
2. **HTTPS** — всегда используйте HTTPS в production
3. **Доступ к сокету** — только для trusted users
4. **Firewall** — ограничьте доступ к порту 9000/9443
5. **Регулярные обновления** — обновляйте Portainer

### **Production-настройка:**
```bash
# Запуск с ограничениями ресурсов
docker run -d \
  --name portainer \
  --memory="512m" \
  --cpus="1.0" \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  --restart always \
  portainer/portainer-ce:latest
```

## **🚀 Продвинутые возможности**

### **1. Шаблоны (Templates):**
Portainer имеет встроенные шаблоны для быстрого развёртывания:
- WordPress
- MySQL, PostgreSQL, MongoDB
- Nginx, Apache
- Jenkins, GitLab

### **2. Реестр образов (Registries):**
Подключение к:
- Docker Hub
- AWS ECR
- Azure Container Registry
- GitLab Registry
- Private registries

### **3. Webhooks:**
Автоматические действия по событиям:
- Авто-деплой при пуше в Git
- Перезапуск контейнеров
- Оповещения в Slack/Telegram

## **📝 Примеры использования**

### **Создание сети и контейнеров:**
1. **Networks** → **Add network**
   - Name: `app-network`
   - Driver: `bridge`
2. **Containers** → **Add container**
   - Name: `web`
   - Image: `nginx`
   - Network: `app-network`

### **Резервное копирование:**
```bash
# Бэкап данных Portainer
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine \
  tar -czf /backup/portainer-backup-$(date +%Y%m%d).tar.gz -C /data .

# Восстановление
docker run --rm -v portainer_data:/data -v $(pwd):/backup alpine \
  tar -xzf /backup/portainer-backup.tar.gz -C /data
```

## **🛠️ Устранение проблем**

### **Если Portainer не запускается:**
```bash
# Проверьте логи
docker logs portainer

# Проверьте, занят ли порт
sudo netstat -tulpn | grep :9000

# Удалите и пересоздайте
docker stop portainer
docker rm portainer
docker volume rm portainer_data
# Запустите заново
```

### **Если нет доступа к Docker:**
```bash
# Проверьте права на docker.sock
ls -la /var/run/docker.sock

# Добавьте пользователя в группу docker
sudo usermod -aG docker $USER
```

## **🎯 Шпаргалка по Portainer**

| Страница | Что там делать |
|----------|----------------|
| **Dashboard** | Общий обзор, быстрые действия |
| **Containers** | Управление контейнерами, логи, консоль |
| **Images** | Скачивание, удаление образов |
| **Networks** | Создание сетей, подключение контейнеров |
| **Volumes** | Управление томами, бэкапы |
| **Stacks** | Docker Compose, развёртывание приложений |
| **Users** | Управление пользователями и правами |
| **Settings** | Настройки Portainer, шаблоны |

## **📱 Доступ с мобильного**

Portainer полностью адаптивен:
- Откройте в браузере телефона: `http://ВАШ-IP:9000`
- Все функции доступны
- Можно управлять Docker с телефона!

## **🔄 Обновление Portainer**

```bash
# Остановить и удалить старый контейнер
docker stop portainer
docker rm portainer

# Скачать новый образ
docker pull portainer/portainer-ce:latest

# Запустить с теми же томами
docker run -d \
  --name portainer \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  --restart unless-stopped \
  portainer/portainer-ce:latest
```

## **✅ Итог**

**Portainer** — это:
1. **Удобство** — управление Docker без командной строки
2. **Наглядность** — всё в веб-интерфейсе с графиками
3. **Безопасность** — ролевой доступ, HTTPS
4. **Мощность** — полная функциональность Docker API
5. **Бесплатно** — Community Edition с открытым кодом

**Идеально для:**
- Начинающих изучать Docker
- Команд разработки
- Простых production-окружений
- Образовательных целей
- Быстрого прототипирования

**Запустите и убедитесь сами:**
```bash
docker run -d \
  --name portainer \
  -p 9000:9000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  portainer/portainer-ce
```
Откройте `http://localhost:9000` и начинайте управлять Docker через красивый веб-интерфейс! 🎪
> Если вы обраружили ошибку в этом тексте - сообщите пожалуйста автору!

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
