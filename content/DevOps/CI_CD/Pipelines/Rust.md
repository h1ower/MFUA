## Pipeline CI на Rust в GitHub Actions

**Цель** — учебный пример — простой проект, который можно склонировать, настроить и убедиться, что приложение в контейнере с **Rust**, и **GitHub Actions** работает

Вы научитесь:
- Настроить **CI** для **Rust** проектов
- Научиться контейнеризировать приложения с **Docke**
- Сборку Docker-образа
- Сохранение артефактов для локального использования

**Rust** — это современный язык программирования общего назначения, ориентированный на безопасность, скорость и параллелизм

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!

### 1. Создайте на **GitHub** новый публичный репозиторий `my-rust-app` с `README.md`

Склонируйте его себе, откройте в **VS Code** и создайте такую структуру будущего проекта:

Структура проекта
```
my-rust-app/
├── .github/
│   └── workflows/
│       └── rust-ci.yml
├── src/
│   └── main.rs
├── Cargo.toml
├── Cargo.lock
├── Dockerfile # ваш Dockerfile для сборки приложения
├── .dockerignore
├── .gitignore
└── README.md
```

Структуру проекта можно сделать одной **bash**-командой, которая автоматически создаст все файлы и каталоги проекта:
```shell
mkdir -p .github/workflows src && \
touch .github/workflows/rust-ci.yml \
      Cargo.toml Cargo.lock .dockerignore .gitignore src/main.rs \
      Dockerfile README.md
```

### 2. Файл `.github/workflows/rust-ci.yml`
```yaml
name: Rust CI Pipeline

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

env:
  CARGO_TERM_COLOR: always
  IMAGE_NAME: my-rust-app

jobs:
  # Job 1: Линтинг и форматирование
  lint:
    name: Lint & Format
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          components: rustfmt, clippy
          override: true

      - name: Check formatting
        run: cargo fmt --all -- --check

      - name: Run Clippy (linter)
        run: cargo clippy -- -D warnings

  # Job 2: Сборка и тестирование
  test:
    name: Build & Test
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          profile: minimal
          toolchain: stable
          override: true

      # Быстрая проверка типов (экономит время при ошибках)
      - name: Check code (fast)
        run: cargo check --verbose

      # Проверка debug-сборки
      - name: Check debug build
        run: cargo build --verbose

      # Проверка release-сборки (важно для production)
      - name: Check release build
        run: cargo build --release --verbose

      # Запуск тестов
      - name: Run tests
        run: cargo test --verbose

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
        uses: docker/build-push-action@v5
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

### 3. Файл `Cargo.toml`
```toml
[package]
name = "my-rust-app"
version = "0.1.0"
edition = "2021"

[dependencies]

[profile.release]
lto = true
codegen-units = 1
opt-level = 3
```

### 4. Файл `src/main.rs`
```rust
use std::io::{self, Write};

fn main() {
    println!("Hello from Rust in Docker! 🦀");
    // Принудительный сброс буфера вывода
    io::stdout().flush().unwrap();
    // Небольшая задержка для гарантии вывода в контейнере
    std::thread::sleep(std::time::Duration::from_millis(200));
}

```
> пустая строка в конце кода на Rust обязательна!

### 5. Файл `Dockerfile`
```dockerfile
# ---- Этап 1: Сборка приложения ----
FROM rust:1-slim AS builder
WORKDIR /app
# Копируем файлы с зависимостями
COPY Cargo.toml Cargo.lock ./
# Создаём фиктивный main.rs для сборки зависимостей
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -f target/release/my-rust-app*
# Копируем реальный исходный код и собираем
COPY src ./src
RUN cargo build --release
# ---- Этап 2: Минимальный образ для запуска ----
FROM debian:stable-slim
# Создаём непривилегированного пользователя
RUN useradd --create-home appuser
WORKDIR /home/appuser
# Копируем скомпилированный бинарник
COPY --from=builder /app/target/release/my-rust-app .
# Переключаемся на пользователя
USER appuser
# Запуск приложения
CMD ["./my-rust-app"]
```

### 6. Файл `.dockerignore`
```dockerignore
target/
.git/
.github/
.gitignore
.dockerignore
*.md
*.log
Dockerfile
```

### 7. Файл  `.gitignore`
```gitignore
/target/
**/*.rs.bk
*.swp
/.idea/
*.iml
```

### 8. Файл `Cargo.lock` остаётся пустым

Файл `Cargo.lock` создаётся автоматически при первой сборке. Вы можете оставить его пустым или не создавать вовсе — он сгенерируется в CI.

### 9. Проверить сборку онлайн

- Закоммитьте и запушите в ветку `main` эти файлы в ваш репозиторий
- Перейдите на вкладку **Actions** в вашем репозитории на **GitHub**. Вы увидите, как ваш **Workflow** запустился, а через несколько минут загорится **зеленая** галочка, которая означает, что все шаги прошли успешно
- Если ваш **Workflow** стал красным - исправьте ошибки и запуштесь снова

![Скрин](/content/DevOps/CI_CD/img/11_workflow.png)

### 10. Проверить сборку Docker-образа локально

На своём компьютере, находясь в папке `my-rust-app` этого репозитория выполнить:

Собрать Docker-образ:
```shell
docker build -t my-rust-app:latest .
```
Проверьте, что образ создался:
```shell
docker images | grep my-rust-app
```
Запуск контейнера:
```shell
docker run --rm my-rust-app:latest
```
![Hello from my Rus app!](/content/DevOps/CI_CD/img/9_workflow.png)

войти в контейнер в интерактивном режиме
```shell
docker run -it --rm --entrypoint /bin/bash my-rust-app:latest
```
![Hello from my Rus app!](/content/DevOps/CI_CD/img/10_workflow.png)

выйти из контейнера:
```shell
exit
```
