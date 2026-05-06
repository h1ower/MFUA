## Pipeline CI на Node.js в GitHub Actions

**Цель** — учебный пример — простой проект, который можно склонировать, настроить и убедиться, что приложение в контейнере с Node.js, и GitHub Actions работает

Вы научитесь:
- Настроить **CI** для **Node.js** проектов
- Научиться контейнеризировать приложения с **Docker**
- Сборку Docker-образа
- Сохранение артефактов для локального использования

### 1. Создайте на **GitHub** новый публичный репозиторий `my-node-app` с `README.md`

Склонируйте его себе, откройте в **VS Code** и создайте такую структуру будущего проекта:

Структура проекта
```
my-node-app/
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   └── index.js            # основной код
├── tests/
│   └── index.test.js       # тесты (Jest)
├── package.json            # зависимости и скрипты
├──.eslintrc.json
├── Dockerfile
└── README.md
```

Структуру проекта можно сделать одной bash-командой, которая автоматически создаст все файлы и каталоги проекта:
```shell
mkdir -p .github/workflows src tests && \
touch .github/workflows/ci.yml src/index.js tests/index.test.js package.json .eslintrc.json Dockerfile README.md
```

### 2. Файл `package.json` (зависимости и скрипты)
```json
{
  "name": "my-node-app",
  "version": "1.0.0",
  "description": "Пример CI для Node.js",
  "main": "src/index.js",
  "scripts": {
    "test": "jest",
    "lint": "eslint src",
    "start": "node src/index.js"
  },
  "devDependencies": {
    "eslint": "^8.56.0",
    "jest": "^29.7.0"
  }
}
```

### 3. Файл `src/index.js` (основной код)
```javascript
function add(a, b) {
    return a + b;
}
function main() {
    console.log("Hello from Node.js app!");
}
if (require.main === module) {
    main();
}
module.exports = { add };
```

### 4. Файл `tests/index.test.js` (тесты)
```javascript
const { add } = require('../src/index');

test('adds 2 + 3 to equal 5', () => {
    expect(add(2, 3)).toBe(5);
});

test('adds -1 + 1 to equal 0', () => {
    expect(add(-1, 1)).toBe(0);
});

test('adds 0 + 0 to equal 0', () => {
    expect(add(0, 0)).toBe(0);
});
```

### 4. Файл `Dockerfile`
```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
CMD ["node", "src/index.js"]
```

### 5. Файл `.github/workflows/ci.yml`
```yaml
name: CI for Node.js App

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    name: Lint & Test
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x, 20.x, 22.x]
    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm test

  docker-build:
    name: Build Docker Image (no push)
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t my-node-app:test .
```

### 6. Конфигурационного файл `.eslintrc.json`
```json
{
  "env": {
    "node": true,
    "jest": true
  },
  "extends": "eslint:recommended",
  "parserOptions": {
    "ecmaVersion": 2021
  },
  "rules": {
    "no-unused-vars": "warn"
  }
}
```

Что делает этот конфиг?
- env – говорит ESLint, что код выполняется в среде Node.js и используются глобальные переменные Jest (describe, test, expect и т.д.), чтобы не было ложных предупреждений.
- extends: "eslint:recommended" – включает набор рекомендуемых правил.
- parserOptions – указывает современную версию JavaScript (ECMAScript 2021).
- rules – настраивает правило: предупреждать о неиспользуемых переменных, но не прерывать выполнение.

### 7. Сгенерировать в папке `my-node-app` файл `package-lock.json` через `Docker` (без локальной установки `Node.js`)

> ### Вам не нужно устанавливать Node.js на свою ОС. Используйте Docker, который у вас уже есть!

Для Windows PowerShell
```shell
docker run --rm -v "${PWD}:/app" -w /app node:18-alpine npm install --package-lock-only
```
Для любого Unix
```shell
docker run --rm -v "$(pwd):/app" -w /app node:18-alpine npm install --package-lock-only
```

### 8. Проверить сборку онлайн

- Закоммитьте и запушите в ветку `main` эти файлы в ваш репозиторий
- Перейдите на вкладку **Actions** в вашем репозитории на **GitHub**. Вы увидите, как ваш **Workflow** запустился, а через несколько минут загорится **зеленая** галочка, которая означает, что все шаги прошли успешно
- Если ваш **Workflow** стал красным - исправьте ошибки и запуштесь снова

![Скрин](/content/DevOps/CI_CD/img/4_workflow.png)

### 7. Проверить сборку Docker-образа локально

На своём компьютере, находясь в папке `my-node-app` этого репозитория выполнить:

Сборка проекта в Docker-образ
```shell
docker build -t my-node-app:latest .
```
Создание и запуск контейнера:
```shell
docker run --rm my-node-app:latest
```

Вы увидите вывод: `Hello from Node.js app!`

![Hello from my Python app!](/content/DevOps/CI_CD/img/3_workflow.png)

Опционально вы можете зайти в интерактивный режим контейнера для ознакомления и отладки:
```shell
docker run --rm -it my-node-app:latest /bin/sh
```
выйти из контейнра:
```shell
exit
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
