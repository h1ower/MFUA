## Pipeline CI на PHP в GitHub Actions

**Цель** — учебный пример — простой проект, который можно склонировать, настроить и убедиться, что приложение в контейнере на **PHP**, и **GitHub Actions** работает

Вы научитесь:
- Настроить **CI** для **PHP** проектов
- Научиться контейнеризировать приложения с **Docker**
- Автоматическую проверку синтаксиса PHP
- Запуск unit-тестов (PHPUnit)
- Сборку Docker-образа
- Сохранение артефактов для локального использования

### 1. Создайте на **GitHub** новый публичный репозиторий `my-php-app` с `README.md`

Склонируйте его себе, откройте в **VS Code** и создайте такую структуру будущего проекта:

Структура проекта
```
my-php-app/
├── .github/
│   └── workflows/
│       └── ci.yml
├── src/
│   └── index.php
├── tests/
│   └── test.php
├── Dockerfile
├── .dockerignore
└── README.md
```


Структуру проекта можно сделать одной **bash**-командой, которая автоматически создаст все файлы и каталоги проекта:
```shell
mkdir -p .github/workflows src tests && \
touch .github/workflows/ci.yml \
      src/index.php tests/test.php \
      Dockerfile .dockerignore README.md && cd my-php-app
```

### 2. Файл `src/index.php`
```php
<?php

function getGreeting() {
    return "Hello from PHP in Docker! 🐳";
}

echo getGreeting() . PHP_EOL;
```

### 3. Файл `tests/test.php`
```php
<?php
use PHPUnit\Framework\TestCase;

class GreetingTest extends TestCase
{
    public function testGetGreeting()
    {
        require_once __DIR__ . '/../src/index.php';

        $greeting = getGreeting();
        $this->assertEquals("Hello from PHP in Docker! 🐳", $greeting);
        $this->assertStringContainsString("PHP", $greeting);
        $this->assertStringContainsString("Docker", $greeting);
    }
}
```

### 4. Файл `Dockerfile`
```dockerfile
# ---- Этап 1: Сборка и тестирование ----
FROM php:8.2-cli AS builder

WORKDIR /app

# Копируем исходники
COPY src ./src

# ---- Этап 2: Минимальный образ для запуска ----
FROM php:8.2-cli

# Создаём непривилегированного пользователя
RUN useradd --create-home appuser
WORKDIR /home/appuser

# Копируем приложение
COPY --from=builder /app/src ./app

USER appuser

CMD ["php", "./app/index.php"]
```

### 5. Файл `.dockerignore`
```dockerignore
.git/
.github/
.gitignore
.dockerignore
*.md
*.log
Dockerfile
tests/
vendor/
composer.*
```

### 6. Файл `.github/workflows/ci.yml`
```yaml
name: PHP CI Pipeline

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

env:
  IMAGE_NAME: my-php-app

jobs:
  # Job 1: Линтинг (проверка синтаксиса)
  lint:
    name: Syntax Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          tools: composer

      - name: Validate composer.json (если есть)
        run: composer validate --no-check-all --strict || true

      - name: Check PHP syntax
        run: |
          find src -name "*.php" -exec php -l {} \;
          find tests -name "*.php" -exec php -l {} \; || true

  # Job 2: Тестирование
  test:
    name: Run Tests
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.2'
          tools: composer, phpunit

      - name: Install dependencies
        run: |
          composer require --dev phpunit/phpunit || true
          composer install --no-progress --no-suggest

      - name: Run PHPUnit tests
        run: |
          if [ -f vendor/bin/phpunit ]; then
            vendor/bin/phpunit tests/
          else
            echo "PHPUnit not installed, skipping tests"
          fi

  # Job 3: Сборка Docker образа
  docker-build:
    name: Build Docker Image
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          load: true
          tags: ${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Save Docker image as artifact
        run: |
          docker save ${{ env.IMAGE_NAME }}:latest -o /tmp/docker-image.tar
          gzip /tmp/docker-image.tar

      - name: Upload Docker image artifact
        uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: /tmp/docker-image.tar.gz
          retention-days: 7

      - name: Test Docker image
        run: docker run --rm ${{ env.IMAGE_NAME }}:latest
```

### 7. Проверить сборку онлайн

- Закоммитьте и запушите в ветку `main` эти файлы в ваш репозиторий
- Перейдите на вкладку **Actions** в вашем репозитории на **GitHub**. Вы увидите, как ваш **Workflow** запустился, а через несколько минут загорится **зеленая** галочка, которая означает, что все шаги прошли успешно
- Если ваш **Workflow** стал красным - исправьте ошибки и запуштесь снова
- Вывод — Hello from PHP in Docker! 🐳

![Скрин](/content/DevOps/CI_CD/img/15_workflow.png)

### 8. Проверить сборку Docker-образа локально

```shell
docker build -t my-php-app:latest .
```
Запустить контейнер
```shell
docker run --rm my-php-app:latest
```

![Скрин](/content/DevOps/CI_CD/img/14_workflow.png)

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
