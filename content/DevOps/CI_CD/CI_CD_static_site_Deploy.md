## CI/CD статического сайта (HTML + CSS + JS) на GitHub Pages

**Деплой чистого статического сайта на живой URL через GitHub Pages, Environments и Deployments**

> **Лабораторная работа выполняется в VS Code!**

**GitHub Pages** — бесплатный хостинг **статических сайтов**. Для HTML+CSS+JS — идеальный вариант: **шаг сборки не нужен**, файлы деплоятся **как есть**.

**GitHub Environments** — логические окружения (`production`), к которым привязываются деплои.

**GitHub Deployments** — история развёртываний.

**CDN** — сеть серверов по всему миру для быстрой раздачи статики. GitHub Pages использует CDN автоматически.

**Цель** — задеплоить статический сайт на GitHub Pages через **настоящий CI/CD** (с гейтингом `needs: ci`).

Что узнаете:
- **Валидация HTML/CSS/JS** без сборки
- **`html-validate`**, **`stylelint`**, **`eslint`** — линтеры для статики
- **`actions/upload-pages-artifact`** — прямая загрузка папки без сборки
- **`needs: ci`** — гейтинг деплоя на CI (настоящий CD)
- **`environment: github-pages`** — привязка к окружению
- **Относительные пути** — почему здесь **нет проблемы с `base`**

> 💡 **Главное отличие от React-проекта:** здесь **нет сборки**. Файлы `index.html`, `style.css`, `script.js` деплоятся **напрямую**. Это самый простой пример «живого деплоя».

### 1. Создайте структуру проекта

```text
hello-static/
├── .github/workflows/
│   └── ci-cd.yml
├── public/                  ← ЭТА ПАПКА ДЕПЛОИТСЯ НА PAGES
│   ├── favicon.svg
│   ├── index.html
│   ├── script.js
│   └── style.css
├── .gitignore
├── .htmlvalidate.json
├── .stylelintrc.json
├── eslint.config.js
└── package.json
```

> 💡 **Папка `public/`** — то, что уедет на Pages. Если положить файлы в корень, то придётся исключать `package.json`, `.github/` и прочее через `.gitignore` и дополнительные настройки. С `public/` — чище.

Для перехода в корень текущего пользователя:

```shell
cd ~
```

Создать структуру одной bash-командой (**Git Bash / Linux / WSL / macOS**):

```shell
mkdir -p hello-static/{.github/workflows,public} && \
cd hello-static && \

cat > package.json << 'EOF'
{
  "name": "hello-static",
  "private": true,
  "type": "module",
  "version": "0.1.0",
  "scripts": {
    "lint": "npm run lint:html && npm run lint:css && npm run lint:js",
    "lint:html": "html-validate \"public/**/*.html\"",
    "lint:css": "stylelint \"public/**/*.css\"",
    "lint:js": "eslint \"public/**/*.js\""
  },
  "devDependencies": {
    "@eslint/js": "^9.13.0",
    "eslint": "^9.13.0",
    "globals": "^15.11.0",
    "html-validate": "^8.24.0",
    "stylelint": "^16.10.0",
    "stylelint-config-standard": "^36.0.1"
  }
}
EOF

cat > .htmlvalidate.json << 'EOF'
{
  "extends": ["html-validate:recommended"]
}
EOF

cat > .stylelintrc.json << 'EOF'
{
  "extends": ["stylelint-config-standard"]
}
EOF

cat > eslint.config.js << 'EOF'
import js from '@eslint/js'
import globals from 'globals'

export default [
  js.configs.recommended,
  {
    files: ['public/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'script',
      globals: globals.browser,
    },
  },
]
EOF

cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
  <head>
    <meta charset="UTF-8">
    <link rel="icon" type="image/svg+xml" href="./favicon.svg">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hello Static</title>
    <link rel="stylesheet" href="./style.css">
  </head>
  <body>
    <div class="app">
      <header class="header">
        <h1>🚀 Hello Static</h1>
        <p class="subtitle">Статический сайт на HTML + CSS + JS</p>
      </header>

      <main>
        <section class="card">
          <h2>О проекте</h2>
          <p>
            Этот сайт автоматически деплоится на
            <strong>GitHub Pages</strong> при push в <code>main</code>.
            Файлы <code>index.html</code>, <code>style.css</code> и
            <code>script.js</code> уезжают на сервер <strong>как есть</strong> —
            без сборки.
          </p>
        </section>

        <section class="card">
          <h2>Интерактивный счётчик</h2>
          <p>Нажатий: <span id="counter">0</span></p>
          <button id="increment" type="button">Увеличить</button>
        </section>
      </main>

      <footer class="footer">
        <p>Deployed with ❤️ to GitHub Pages</p>
      </footer>
    </div>

    <script src="./script.js"></script>
  </body>
</html>
EOF

cat > public/style.css << 'EOF'
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  color: #333;
}

.app {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem 1rem;
}

.header {
  text-align: center;
  color: white;
  margin-bottom: 2rem;
}

.header h1 {
  font-size: 3rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  font-size: 1.2rem;
  opacity: 0.9;
}

.card {
  background: white;
  border-radius: 12px;
  padding: 1.5rem;
  margin-bottom: 1rem;
  box-shadow: 0 4px 12px rgb(0 0 0 / 15%);
}

.card h2 {
  margin-bottom: 0.75rem;
  color: #764ba2;
}

.card p {
  line-height: 1.6;
}

#counter {
  font-weight: bold;
  font-size: 1.5rem;
  color: #764ba2;
}

#increment {
  margin-top: 0.75rem;
  padding: 0.5rem 1.25rem;
  border: none;
  border-radius: 6px;
  background: #764ba2;
  color: white;
  font-size: 1rem;
  cursor: pointer;
}

#increment:hover {
  background: #5b3a7e;
}

code {
  background: #f0f0f0;
  padding: 0.1rem 0.3rem;
  border-radius: 4px;
  font-size: 0.9em;
}

.footer {
  text-align: center;
  color: white;
  margin-top: 2rem;
  opacity: 0.8;
}
EOF

cat > public/script.js << 'EOF'
const counterElement = document.getElementById('counter')
const incrementButton = document.getElementById('increment')

let count = 0

incrementButton.addEventListener('click', () => {
  count += 1
  counterElement.textContent = String(count)
})
EOF

cat > public/favicon.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <text y="75" font-size="75">🚀</text>
</svg>
EOF

cat > .github/workflows/ci-cd.yml << 'EOF'
name: CI/CD

on:
  push:
    branches: [ main ]
  pull_request:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  # ===== Job 1: CI — валидация статики =====
  ci:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint HTML
        run: npm run lint:html

      - name: Lint CSS
        run: npm run lint:css

      - name: Lint JS
        run: npm run lint:js

      # Загружаем папку public как артефакт для job'а deploy
      - name: Upload public artifact
        uses: actions/upload-artifact@v4
        with:
          name: public
          path: public
          retention-days: 1

  # ===== Job 2: Deploy — только после успешного CI =====
  deploy:
    needs: ci
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest

    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}

    steps:
      - name: Download public artifact
        uses: actions/download-artifact@v4
        with:
          name: public
          path: public

      - name: Setup Pages
        uses: actions/configure-pages@v5

      - name: Upload artifact to Pages
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./public

      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
EOF

cat > .gitignore << 'EOF'
node_modules/
.env
.idea/
.vscode/
*.local
.DS_Store
EOF

echo "✅ Структура создана:"
find . -type f -not -path './node_modules/*' | sort
```

> 💡 **Относительные пути** — `./style.css`, `./script.js`, `./favicon.svg`. Они **работают на GitHub Pages без настройки**. Сайт живёт по адресу `https://<username>.github.io/hello-static/`, и `./style.css` превратится в `/hello-static/style.css` автоматически. **Проблемы с `base`, как в Vite, здесь нет.**

### 2. Генерация `package-lock.json`

Перед первым запуском нужно создать `package-lock.json` — он **обязателен** для `npm ci` в CI.

**Git Bash / Linux / WSL / macOS:**

```shell
cd ~/hello-static
mkdir -p ~/.npm-docker-cache
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -v "$(pwd)":/app \
  -v ~/.npm-docker-cache:/tmp/.npm \
  -w /app \
  node:20-alpine \
  npm install --cache /tmp/.npm
```

**PowerShell (Windows):**

```powershell
cd ~/hello-static
docker run --rm `
  -e HOME=/tmp `
  -v "${PWD}:/app" `
  -w /app `
  node:20-alpine `
  npm install
```

**Проверьте:**

```shell
ls -la package-lock.json
```

Файл появился (~200–300 KB). **Обязательно закоммитьте его** — без него CI упадёт на `npm ci`.

> ⚠️ В выводе могут быть `npm warn deprecated ...` и `N vulnerabilities`. Это **не ошибки**. **Не запускайте `npm audit fix --force`** — сломает проект.

### 3. Локальная валидация

**Git Bash / Linux / WSL / macOS:**

```shell
cd ~/hello-static
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$(pwd)":/app -v ~/.npm-docker-cache:/tmp/.npm \
  -w /app node:20-alpine \
  sh -c "npm ci --cache /tmp/.npm && npm run lint"
```

**PowerShell (Windows):**

```powershell
cd ~/hello-static
docker run --rm `
  -e HOME=/tmp `
  -v "${PWD}:/app" `
  -w /app `
  node:20-alpine `
  sh -c "npm ci && npm run lint"
```

**Ожидаемый вывод:**

```
> hello-static@0.1.0 lint:html
> html-validate "public/**/*.html"

> hello-static@0.1.0 lint:css
> stylelint "public/**/*.css"

> hello-static@0.1.0 lint:js
> eslint "public/**/*.js"
```

**Никаких ошибок** — все три линтера прошли.

### 4. Локальный просмотр сайта

Сборки нет — можно сразу открыть сайт через Nginx:

```shell
cd ~/hello-static
docker run --rm -p 8081:80 \
  -v "$(pwd)/public":/usr/share/nginx/html:ro \
  nginx:alpine
```

Откройте: **`http://localhost:8081/`**

> ⚠️ **Обратите внимание:** здесь **без префикса** `/hello-static/`! Просто `http://localhost:8081/`. Это потому что Nginx раздаёт папку как корень. На GitHub Pages сайт будет по адресу с префиксом, но **относительные пути сами адаптируются**.

**Ожидаемый результат:**
- 🚀 Hello Static
- «О проекте», «Интерактивный счётчик»
- Фиолетовый градиент
- Кнопка **«Увеличить»** работает — счётчик растёт

> ⚠️ **После проверки остановите контейнер** — `Ctrl+C` в терминале.

### 5. Создание пустого репозитория на GitHub

Создайте пустой репозиторий **`hello-static`** на **GitHub**.

> ⚠️ **Не добавляйте** `README.md`, `.gitignore` и лицензию — иначе `push` будет отклонён.

### 6. Включение GitHub Pages в настройках

> ⚠️ **Выполните этот шаг ДО первого `push` в `main`** — иначе workflow упадёт с ошибкой `Pages site not found`.

1. Откройте репозиторий → **Settings** → **Pages**
2. В разделе **Build and deployment** → **Source** выберите **GitHub Actions**
3. **Кнопки Save нет** — настройка применяется автоматически

> 💡 GitHub может не показать подтверждающее сообщение сразу. **Главное — при обновлении страницы Source должен остаться GitHub Actions.**

### 7. Запушить проект

```shell
cd ~/hello-static
```

**Git Bash / Linux / WSL / macOS:**

```shell
git init
git add .
git commit -m "Initial commit: Static site with CI/CD to GitHub Pages"
git branch -M main
read -p "Введите ваш GitHub username: " GITHUB_USER
git remote add origin "https://github.com/${GITHUB_USER}/hello-static.git"
git remote -v
git push -u origin main
```

**PowerShell (Windows):**

```powershell
git init
git add .
git commit -m "Initial commit: Static site with CI/CD to GitHub Pages"
git branch -M main
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
git remote add origin "https://github.com/$GITHUB_USER/hello-static.git"
git remote -v
git push -u origin main
```

> ⚠️ **Убедитесь, что `package-lock.json` попал в коммит.** Проверьте: `git ls-files | grep package-lock`.

### 8. Первый запуск CI/CD

После `push` в `main` откройте вкладку **Actions** в **GitHub**.

**Что произойдёт:**
- **Job `ci`** запустится: `npm ci`, `lint:html`, `lint:css`, `lint:js`, загрузка артефакта (~1–2 минуты)
- **Job `deploy`** будет **ждать** — `needs: ci`
- Когда `ci` завершится **✅ зелёным** — `deploy` запустится: скачает артефакт, задеплоит на Pages (~30 секунд)
- Если `ci` **упадёт ❌** — `deploy` **не запустится** (это и есть настоящий CD)

> 💡 **Визуально в Actions:**
> ```
> CI/CD
> ├── ✅ ci
> └── ✅ deploy (needs: ci)
> ```

### 9. Проверка деплоя

#### 9.1. Environments

```
https://github.com/<ВАШ-USERNAME>/hello-static/settings/environments
```

Или через меню: **Settings → Environments**.

Там будет **`github-pages`** с кликабельной ссылкой на живой сайт.

> 💡 **Почему Environment не виден в правой колонке?** Потому что он создан **автоматически** Actions, у вас **только один** environment, и у него **нет** protection rules. Когда добавите reviewers или второй environment — ссылка появится.

#### 9.2. Deployments

```
https://github.com/<ВАШ-USERNAME>/hello-static/deployments
```

История всех развёртываний.

#### 9.3. Живой URL

**Ссылка на сайт в новом UI GitHub НЕ появляется автоматически на главной странице.** Добавьте вручную:

1. Главная страница репозитория → блок **About** → ⚙️
2. Поставьте галочку **Use your GitHub Pages website**
3. **Save changes**

Откройте в браузере:

```
https://<ВАШ-USERNAME>.github.io/hello-static/
```

**Ожидаемый результат:** страница с заголовком **«🚀 Hello Static»**, работающая кнопка **«Увеличить»**, фиолетовый градиент.

> ⚠️ **Первый деплой может занять 5–10 минут** — GitHub регистрирует сайт в CDN. Последующие деплои мгновенные.

### 10. Обновление сайта

Внесите изменения (например, в `public/style.css`), закоммитьте и запушьте:

```shell
cd ~/hello-static

# 1. Откройте public/style.css в VS Code и измените цвет

# 2. Валидация
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$(pwd)":/app -v ~/.npm-docker-cache:/tmp/.npm \
  -w /app node:20-alpine \
  sh -c "npm ci --cache /tmp/.npm && npm run lint"

# 3. Локальный просмотр (опционально)
docker run --rm -p 8081:80 \
  -v "$(pwd)/public":/usr/share/nginx/html:ro \
  nginx:alpine
# Откройте http://localhost:8081/ и остановите через Ctrl+C

# 4. Коммит и push
git add .
git commit -m "style: update card shadow"
git push origin main
```

**Что произойдёт:**
- ✅ Job `ci` пройдёт все проверки
- ✅ Job `deploy` запустится **только после** успешного CI
- ✅ Через 1–2 минуты изменения будут **на живом сайте**

> 💡 **Никаких тегов для деплоя!** В отличие от Releases (где нужен тег), Pages деплоится **на каждый push в main**.

### 11. Continuous Delivery vs Continuous Deployment

> 💡 **Что означает «настоящий CD»:**
>
> | Тип | Что делает | Наш проект |
> |-----|-----------|:---:|
> | **Continuous Integration (CI)** | Автоматически проверяет код | ✅ `job: ci` |
> | **Continuous Delivery (CDel)** | Готовит релиз, деплой — вручную | ❌ |
> | **Continuous Deployment (CDep)** | Деплоит автоматически после CI | ✅ `job: deploy` |
>
> **Мы реализовали Continuous Deployment:**
> - Push в `main` → CI → **если CI ✅** → автоматический деплой
> - Никакого ручного approval
> - `needs: ci` — критично: **deploy не запустится, если CI упал**
>
> **Если бы хотели Continuous Delivery** — добавили бы `environment: production` с **required reviewers**. Тогда деплой ждал бы ручного подтверждения.

### 12. Если что-то не работает

> **`Pages site not found`**
>
> Забыли включить Pages: **Settings → Pages → Source: GitHub Actions**.

> **`Resource not accessible by integration`**
>
> В `ci-cd.yml` не хватает прав:
> ```yaml
> permissions:
>   contents: read
>   pages: write
>   id-token: write
> ```

> **`npm ci can only install with an existing package-lock.json`**
>
> Не сгенерирован `package-lock.json` — вернитесь к шагу 2.

> **Job `deploy` не запускается**
>
> Это **правильное поведение**! Job `deploy` имеет `needs: ci` — он ждёт, пока CI завершится. Если CI **упал** — `deploy` **не запустится** (это и есть настоящий CD).

> **Стили не применяются на живом сайте**
>
> Проверьте пути в `public/index.html` — они должны быть **относительными**:
> ```html
> <link rel="stylesheet" href="./style.css">
> <script src="./script.js"></script>
> ```
> Если там `/style.css` (абсолютный путь) — стили сломаются.

> **`html-validate` ругается на `doctype-style` и `void-style`**
>
> `html-validate:recommended` требует **классический HTML5-стиль**:
> - `<!DOCTYPE html>` — **заглавные буквы**
> - `<meta>`, `<link>`, `<img>`, `<br>` — **без `/` в конце**
>
> **Правильно:**
> ```html
> <!DOCTYPE html>
> <meta charset="UTF-8">
> <link rel="stylesheet" href="./style.css">
> ```
>
> **Неправильно:**
> ```html
> <!doctype html>
> <meta charset="UTF-8" />
> <link rel="stylesheet" href="./style.css" />
> ```
>
> **Альтернатива** — отключить правила в `.htmlvalidate.json`:
> ```json
> {
>   "extends": ["html-validate:recommended"],
>   "rules": {
>     "void-style": "off",
>     "doctype-style": "off"
>   }
> }
> ```

> **`stylelint` ругается на `rgb(0 0 0 / 15%)`**
>
> Это **современный синтаксис** CSS Color 4. Stylelint со стандартным конфигом его принимает. Если ругается — обновите `stylelint-config-standard`.

> **`Concurrency limit exceeded`**
>
> Два деплоя одновременно. `concurrency: pages` должен предотвращать — дождитесь завершения первого.

> **Ссылка на сайт не появляется на главной странице**
>
> В новом UI GitHub ссылка **не отображается автоматически**. Добавьте вручную через **About → ⚙️ → Use your GitHub Pages website**.

### 13. Краткая шпаргалка

```shell
# 1. Изменить код (откройте в VS Code)
#    - public/index.html, public/style.css, public/script.js

# 2. Проверить локально
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$(pwd)":/app -v ~/.npm-docker-cache:/tmp/.npm \
  -w /app node:20-alpine \
  sh -c "npm ci --cache /tmp/.npm && npm run lint"

# 3. Закоммитить и запушить
git add .
git commit -m "feat: update content"
git push origin main

# 4. Подождать 1–2 минуты, открыть
#    https://<username>.github.io/hello-static/
```

### Что вы освоили

- **Валидация статики** — `html-validate`, `stylelint`, `eslint` без сборки
- **GitHub Pages** — бесплатный хостинг статики с HTTPS
- **CDN** — как GitHub раздаёт статику по всему миру
- **Относительные пути** — почему здесь **нет проблемы с `base`**
- **`actions/upload-artifact` / `download-artifact`** — передача папки между job'ами
- **`actions/upload-pages-artifact`** с `path: ./public` — прямая загрузка **без сборки**
- **`needs: ci`** — гейтинг деплоя на CI (**настоящий CD**)
- **`environment: github-pages`** — привязка job к окружению
- **`permissions: pages: write`** — права для деплоя
- **`concurrency: pages`** — защита от параллельных деплоев
- **Environments и Deployments** — история развёртываний
- **Continuous Deployment vs Continuous Delivery** — разница на практике

### Ключевые отличия от React-проекта

| Аспект | React SPA | **Hello Static** |
|--------|:---:|:---:|
| **Сборка** | Vite + tsc | **Нет сборки** |
| **`base` path** | Обязателен | **Не нужен** (относительные пути) |
| **`package-lock.json`** | Нужен для сборки | **Нужен только для линтеров** |
| **CI-проверки** | lint + types + tests + build | **lint HTML/CSS/JS** |
| **Что деплоится** | Папка `dist/` после сборки | **Папка `public/` как есть** |
| **Время до продакшена** | 2–3 минуты | **30–60 секунд** |
| **Сложность** | Средняя | **Низкая** |

> **Главный урок:** статический сайт **не требует сборки**. Достаточно **относительных путей** и `actions/upload-pages-artifact` с `path: ./public` — и сайт уезжает на Pages. А `needs: ci` делает это **настоящим CD** — деплой не запустится, если валидация упала.

> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!