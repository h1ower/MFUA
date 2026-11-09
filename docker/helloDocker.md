
# Добро пожаловать в Docker 🐳

## 🔍 Проверка порта 8088

```bash
netstat -aon | findstr :8088
```

![Проверка порта](img/helloDocker/2026-03-31_09-32-32.png)

---

## 🚀 Запуск контейнера

```bash
docker run -d -p 8088:80 --name welcome-to-docker docker/welcome-to-docker
```

![Запуск контейнера](img/helloDocker/2026-03-31_09-35-14.png)

---

## 🌐 Страница в браузере

[http://localhost:8088](http://localhost:8088)

![Браузер](img/helloDocker/2026-03-31_09-35-56.png)

---

## 🐚 Вход в контейнер

```bash
docker exec -it welcome-to-docker /bin/sh
```

![Вход в контейнер](img/helloDocker/2026-03-31_09-36-42.png)

---

## 💻 Информация об ОС

```bash
uname -a
```

![uname -a](img/helloDocker/2026-03-31_09-37-04.png)

---

## 📊 Диспетчер ресурсов (top)

```bash
top
```

![top](img/helloDocker/2026-03-31_09-37-58.png)

---

## 🔄 Обновление пакетов

```bash
apk update && apk upgrade
```

![apk update](img/helloDocker/2026-03-31_09-39-49.png)

---

## 📦 Установка fastfetch

```bash
apk add fastfetch
```

![Установка fastfetch](img/helloDocker/2026-03-31_09-40-50.png)

---

## ✨ Запуск fastfetch

```bash
fastfetch
```

![fastfetch](img/helloDocker/2026-03-31_09-41-26.png)

---
