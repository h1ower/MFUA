## Dockerfile. Node.js-приложение

**Node.js** — это бесплатная кросс‑платформенная среда выполнения **JavaScript** с открытым исходным кодом. Она позволяет запускать JavaScript‑код не в браузере, а на сервере или локальном компьютере.

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
my-node-app/
├── package.json
├── app.js
└── Dockerfile
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p my-node-app && touch my-node-app/Dockerfile my-node-app/package.json my-node-app/app.js my-node-app/.dockerignore && cd my-node-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# ---- Базовый образ для сборки ----
FROM node:20-alpine AS builder
WORKDIR /app
# Копируем файлы описания зависимостей
COPY package*.json ./
# Устанавливаем только production-зависимости (без dev)
RUN npm install --omit=dev
# ---- Финальный образ ----
FROM node:20-alpine
# Создаём непривилегированного пользователя
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
WORKDIR /app
# Копируем node_modules из этапа builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
# Копируем исходный код приложения
COPY --chown=nodejs:nodejs . .
# Переключаемся на непривилегированного пользователя
USER nodejs
# Указываем порт, который слушает приложение
EXPOSE 3000
# Запускаем приложение
CMD ["node", "app.js"]
```

### 3. Содержимое файла `package.json`
```json
{
  "name": "my-node-app",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

### 4. Содержимое файла `app.js` (простой веб-сервер)
```javascript
const express = require('express');
const app = express();
const port = 3000;
app.get('/', (req, res) => {
  res.send('Hello from Node.js in Docker! 🐳');
});
app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
```

### 5. Содержимое файла `.dockerignore` (опционально)
```
node_modules
npm-debug.log
.git
.gitignore
README.md
```

### 6. Сборка и запуск

В командной строке, находясь в папке `my-node-app`, выполнить:
```shell
docker build -t my-node-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера контейнера с пробросом порта:
```shell
docker run -d -p 3000:3000 --name my-node-app my-node-app
```

[Откройте в браузере http://localhost:3000, чтобы увидеть приветствие](http://localhost:3000)

### Для разработки (с автоматическим обновлением кода) - не обазательно!

Если вы хотите, чтобы изменения в коде сразу применялись без пересборки образа, используйте монтирование тома:

```shell
docker run -d -p 3000:3000 -v $(pwd):/app --name my-node-app-dev my-node-app
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
