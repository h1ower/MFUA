## Dockerfile. Приложение на Rust

**Rust** — это современный язык программирования общего назначения, ориентированный на безопасность, скорость и параллелизм

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта

```
rust-docker/
├── Dockerfile
├── Cargo.toml
└── src/
    └── main.rs
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p rust-docker/src && touch rust-docker/Dockerfile rust-docker/Cargo.toml rust-docker/src/main.rs && cd rust-docker
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# ---- Этап 1: Сборка зависимостей и приложения ----
FROM rust:1-slim AS builder
WORKDIR /app
# Копируем только Cargo.toml (Cargo.lock не нужен на этом этапе)
COPY Cargo.toml .
# Создаём фиктивный src/main.rs, чтобы собрать зависимости
RUN mkdir src && echo "fn main() {}" > src/main.rs
# Собираем зависимости (при этом внутри контейнера создастся Cargo.lock)
RUN cargo build --release && rm -f target/release/rust-app*
# Теперь копируем настоящий исходный код
COPY src ./src
# Собираем окончательное приложение
RUN cargo build --release
# ---- Этап 2: Минимальный образ для запуска ----
FROM debian:stable-slim
# Создаём непривилегированного пользователя (рекомендация безопасности)
RUN useradd --create-home appuser
WORKDIR /home/appuser
# Копируем скомпилированный бинарник из этапа сборки
COPY --from=builder /app/target/release/rust-app ./rust-app
# Переключаемся на пользователя (не root)
USER appuser
# Если ваше приложение — веб-сервер, укажите порт
EXPOSE 8081
# Запуск в правильном JSON-формате (сигналы будут работать)
CMD ["./rust-app"]
```

### 3. Содержимое файла `src/main.rs`
```rust
fn main() {
    eprintln!("Hello from Rust inside Docker! 🦀");
    // небольшая задержка для гарантии вывода
    std::thread::sleep(std::time::Duration::from_millis(100));
}
```

### 4. Содержимое файла `Cargo.toml` (конфигурация проекта)
```toml
[package]
name = "rust-app"
version = "0.1.0"
edition = "2021"
[dependencies]
# Здесь будут ваши зависимости, если они нужны
```

### 5. Сборка и запуск

В командной строке, находясь в папке `rust-docker`, выполнить:
```shell
docker build -t rust-app .
```

> Флаг `-t` задает имя образа.

Создание и запуск контейнера:
```shell
docker run -it --rm rust-app
```

> Вы должны увидеть: Hello from Rust inside Docker! 🦀

### 6 Зайти в контейнер

```shell
docker run -it --rm --entrypoint sh rust-app
```
Запустить программу на Rust:
```shell
./rust-app
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
