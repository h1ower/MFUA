## CI/CD на Rust с публикацией в GHCR

Pipeline CI/CD на Rust → GHCR

> **Все лабораторные работы выполняются в VS Code!**

**GHCR** (GitHub Container Registry) — это реестр Docker-образов от **GitHub**. Работает так же, как **Docker Hub**, но не требует отдельной регистрации и токенов — всё через встроенный `GITHUB_TOKEN`

**Цель** — научиться публиковать Docker-образ в GHCR автоматически при push в main. Это превращает CI в CI/CD (Continuous Delivery): код не только проверяется, но и превращается в готовый к развёртыванию артефакт.

Ключевое отличие **CI** от **CI/CD**:
- `CI` — код проверяется: fmt, clippy, test, docker build
- `CI/CD` — то же + образ публикуется в реестр (**GHCR**) и готов к деплою (развёртыванию)

### 1. Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:
```text
hello-rust/
├── .github/workflows/ci.yml
├── src/
│   ├── main.rs
│   └── lib.rs
├── tests/
│   └── integration.rs
├── .gitignore
├── .dockerignore
├── Dockerfile
└── Cargo.toml
```
Для перехода в корень текущего пользователя:
```shell
cd ~
```
Создать структуру проекта одной bash-командой (**Git Bash / Linux / WSL / macOS**):
```shell
mkdir -p hello-rust/{.github/workflows,src,tests} && \
cd hello-rust && \

cat > Cargo.toml << 'EOF'
[package]
name = "hello-rust"
version = "0.1.0"
edition = "2021"

[dependencies]

[profile.release]
opt-level = "z"
lto = true
strip = true
EOF

cat > src/lib.rs << 'EOF'
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

pub fn sum_range(from: i64, to: i64) -> i64 {
    (from..=to).sum()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        assert_eq!(greet("Docker"), "Hello, Docker!");
    }

    #[test]
    fn test_sum_range() {
        assert_eq!(sum_range(1, 10), 55);
    }
}
EOF

cat > src/main.rs << 'EOF'
use hello_rust::{greet, sum_range};

fn main() {
    println!("Hello from Rust in Docker! 🦀🐳");
    println!("OS: {}", std::env::consts::OS);
    println!("Arch: {}", std::env::consts::ARCH);
    println!("{}", greet("Docker"));
    println!("Sum 1..10 = {}", sum_range(1, 10));

    let args: Vec<String> = std::env::args().skip(1).collect();
    if !args.is_empty() {
        println!("Аргументы:");
        for (i, arg) in args.iter().enumerate() {
            println!("  {}: {}", i + 1, arg);
        }
    }
}
EOF

cat > tests/integration.rs << 'EOF'
use hello_rust::{greet, sum_range};

#[test]
fn integration_test_greet() {
    assert_eq!(greet("Rust"), "Hello, Rust!");
    assert!(greet("CI").contains("CI"));
}

#[test]
fn integration_test_sum_large() {
    assert_eq!(sum_range(1, 100), 5050);
}
EOF

cat > Dockerfile << 'EOF'
# Этап 1: сборка
FROM rust:1-slim AS builder
WORKDIR /build

# Копируем манифест
COPY Cargo.toml ./

# Фиктивный main, чтобы собрать зависимости отдельным слоем
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -f target/release/hello-rust target/release/deps/hello_rust-*

# Копируем настоящий исходник
COPY src ./src

# Собираем финальный бинарник
RUN cargo build --release

# Этап 2: запуск
FROM debian:stable-slim

# Непривилегированный пользователь
RUN useradd --create-home appuser
WORKDIR /home/appuser

COPY --from=builder /build/target/release/hello-rust ./hello-rust
USER appuser

ENTRYPOINT ["./hello-rust"]
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: Rust CI/CD

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v7

      - name: Set up Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy

      - name: Cache Cargo
        uses: actions/cache@v6
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            target
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.toml') }}

      - name: Format check
        run: cargo fmt --check

      - name: Lint with Clippy
        run: cargo clippy --all-targets -- -D warnings

      - name: Run tests
        run: cargo test

      - name: Build release
        run: cargo build --release

      - name: Log in to GHCR
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=,format=short
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v7
        with:
          context: .
          push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

cat > .gitignore << 'EOF'
/target
EOF

cat > .dockerignore << 'EOF'
target/
.git/
.github/
*.md
.gitignore
.dockerignore
EOF

echo "✅ Структура создана:"
find . -type f | sort
```

### 2. Сборка проекта и тесты в Docker (Rust на хосте не нужен)

Git Bash / Linux / WSL / macOS:
```shell
cd ~/hello-rust
mkdir -p ~/.cargo-docker-cache
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e CARGO_HOME=/tmp/.cargo \
  -v "$(pwd)":/app \
  -v ~/.cargo-docker-cache:/tmp/.cargo \
  -w /app \
  rust:1-slim \
  cargo test
```
PowerShell:
```powershell
cd ~/hello-rust
docker run --rm `
  -e CARGO_HOME=/tmp/.cargo `
  -v "${PWD}:/app" `
  -w /app `
  rust:1-slim `
  cargo test
```
В PowerShell:
- **Docker Desktop** должен быть запущен
- Папка проекта должна быть в разрешённых для **Docker Desktop** дисках (`Settings` → `Resources` → `File Sharing`)
- Первый запуск может быть долгим

### 3. Сборка Docker-образа

На всякий случай переходим в каталог проекта:
```shell
cd ~/hello-rust
```
Выполняем сборку:
```shell
docker build -t hello-rust .
```

### 4. Запуск контейнера

Запуск:
```shell
docker run --rm hello-rust
```
Ожидаемый вывод:
```shell
Hello from Rust in Docker! 🦀🐳
OS: linux
Arch: x86_64
Hello, Docker!
Sum 1..10 = 55
```
В **GitHub Actions** команды `cargo test`, `cargo build` работают напрямую, потому что runner ubuntu-latest уже содержит `Rust toolchain`. Роль «чистого окружения» играет сам раннер (виртуальная машина на **GitHub**)

### 5. Создание пустого репозитория на GitHub

Создайте пустой репозиторий `hello-rust` на **GitHub**.

⚠️ Не добавляйте сразу `README.md`, `.gitignore` и лицензию — иначе `push` будет отклонён!

### 6. Запушить проект

Находясь в каталоге проекта:

На всякий случай переходим в каталог проекта:
```shell
cd ~/hello-rust
```

1. Инициализация
```shell
git init
```
2. Подготовка
```shell
git add .
```
3. Коммит
```shell
git commit -m "Initial commit: Rust app with Docker and CI/CD to GHCR"
```
4. Ветка main
```shell
git branch -M main
```
5. Создание удалённой копии проекта в интерактивном режиме с командной строки:

Git-Bash
```shell
read -p "Введите ваш GitHub username: " GITHUB_USER
git remote add origin "https://github.com/${GITHUB_USER}/hello-rust.git"
git remote -v
```
powershell
```powershell
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
git remote add origin "https://github.com/$GITHUB_USER/hello-rust.git"
git remote -v
```
6. Пуш
```shell
git push -u origin main
```

### 7. Проверка публикации в GHCR

**Workflow** выполняется ~ 2–3 минуты. Когда появится **зелёная галочка** — образ опубликован

Проверка в **GitHub**:
- Откройте страницу репозитория
- В правой колонке — вкладка `Packages`
- Там будет пакет `hello-rust`

![Image](/content/DevOps/CI_CD/img/16_workflow.png)

### 8. Сделать образ публичным

По умолчанию образ в **GHCR** приватный — только вы можете его скачать.

Чтобы сделать публичным:
- Откройте пакет: `GitHub` → `Packages` → `hello-rust`
- Справа: `Package settings`
- Внизу: `Danger Zone` → `Change visibility` → `Public`
- Подтвердите

После этого `docker pull ghcr.io/<ВАШ-USERNAME>/hello-rust:latest` будет работать без авторизации — как `docker pull nginx`, например.

Увидеть загруженный образ в своём Docker:
```shell
docker images
```

### 9. Проверка локально

**Git Bash / Linux / WSL / macOS:**
```shell
read -p "Введите ваш GitHub username: " GITHUB_USER
docker pull "ghcr.io/${GITHUB_USER}/hello-rust:latest"
docker run --rm "ghcr.io/${GITHUB_USER}/hello-rust"
```
PowerShell:
```powershell
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
docker pull "ghcr.io/$GITHUB_USER/hello-rust:latest"
docker run --rm "ghcr.io/$GITHUB_USER/hello-rust"
```
Ожидаемый результат:
```shell
Hello from Rust in Docker! 🦀🐳
OS: linux
Arch: x86_64
Hello, Docker!
Sum 1..10 = 55
```
Удалить образ
```shell
docker rmi ghcr.io/rurewa/hello-rust:latest
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
