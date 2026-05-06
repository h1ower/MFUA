## Dockerfile. Приложение на TypeScript

**TypeScript** — это надстройка над **JavaScript**, поэтому процесс контейнеризации очень похож на **Node.js**, но с одним важным дополнительным шагом: компиляцией **TypeScript** в **JavaScript** перед запуском

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
my-ts-app/
├── src/
│   └── index.ts # исходный код на TypeScript
├── package.json
├── tsconfig.json
└── Dockerfile
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p my-ts-app/src && touch my-ts-app/Dockerfile my-ts-app/package.json my-ts-app/tsconfig.json my-ts-app/.dockerignore my-ts-app/src/index.ts && cd my-ts-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# ---- Этап 1: Сборка и компиляция TypeScript ----
FROM node:20-alpine AS builder
WORKDIR /app
# Копируем файлы с зависимостями
COPY package*.json tsconfig.json ./
# Устанавливаем ВСЕ зависимости (включая TypeScript и dev-зависимости)
# Используем npm install, так как package-lock.json может отсутствовать
RUN npm install
# Копируем исходный код
COPY src ./src
# Компилируем TypeScript в JavaScript
RUN npm run build
# ---- Этап 2: Финальный образ для запуска ----
FROM node:20-alpine AS runner
WORKDIR /app
# Копируем только готовый JavaScript-код и production-зависимости
# (dev-зависимости, включая TypeScript, уже не нужны)
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./
# Устанавливаем только production-зависимости (без dev)
RUN npm install --omit=dev
# Создаём непривилегированного пользователя для безопасности
USER node
# Указываем порт (если ваше приложение — веб-сервер)
EXPOSE 3000
# Запускаем скомпилированное приложение
CMD ["node", "dist/index.js"]
```

### 3. Содержимое файла `src/index.ts` (простое приложение)
```typescript
const greet = (name: string): void => {
    console.log(`Hello, ${name}! Welcome to TypeScript in Docker! 🐳`);
};
greet('Developer');
```

### 4. Содержимое файла `package.json` (программные зависимости)
```json
{
  "name": "my-ts-app",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "devDependencies": {
    "typescript": "^5.0.0"
  }
}
```

### 5. Содержимое файла `tsconfig.json`
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### 6. Содержимое файла `.dockerignore` (опционально)
```dockerignore
node_modules
dist
.git
.env
*.log
```

### 7. Сборка и запуск

В командной строке, находясь в папке `my-ts-app`, выполнить:
```shell
docker build -t my-ts-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run -it --rm my-ts-app
```

> Вы можете увидеть: `Hello, Developer! Welcome to TypeScript in Docker! 🐳`

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
