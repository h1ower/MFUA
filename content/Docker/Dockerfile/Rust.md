## Dockerfile. Приложение на Rust

**Rust** — это современный язык программирования общего назначения, ориентированный на безопасность, скорость и параллелизм

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта

```
rust-docker/
├── Dockerfile
├── Cargo.toml
├── .dockerignore
└── src/
    └── main.rs
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p rust-docker/src && touch rust-docker/Dockerfile rust-docker/Cargo.toml .dockerignore rust-docker/src/main.rs && cd rust-docker
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# ---- Этап 1: Сборка ----
FROM rust:1-slim AS builder
WORKDIR /app
# 1. Копируем манифест
COPY Cargo.toml .
# 2. Создаём фиктивный main.rs, чтобы собрать зависимости отдельным слоем
RUN mkdir src && echo "fn main() {}" > src/main.rs
# 3. Собираем зависимости (кэшируется, если Cargo.toml не менялся)
RUN cargo build --release
# 4. Удаляем фиктивный бинарник, чтобы не остался в образе
RUN rm -f target/release/rust-app target/release/deps/rust_app-*
# 5. Копируем настоящий исходный код
COPY src ./src
# 6. Собираем финальное приложение
RUN cargo build --release
# ---- Этап 2: Минимальный образ для запуска ----
FROM debian:stable-slim
# Непривилегированный пользователь (безопасность)
RUN useradd --create-home appuser
WORKDIR /home/appuser
# Копируем только собранный бинарник из builder
COPY --from=builder /app/target/release/rust-app ./rust-app
# Переключаемся на непривилегированного пользователя
USER appuser
# Если приложение — веб-сервер, раскомментируйте нужный порт
# EXPOSE 8081
# Запуск в JSON-формате — корректная обработка сигналов
CMD ["./rust-app"]
```

### 3. Содержимое файла `src/main.rs`
```rust
fn main() {
    eprintln!("Hello from Rust inside Docker! 🦀");
    println!("Если вы это видите — всё работает правильно.");

    // Небольшая задержка, чтобы Docker успел захватить вывод
    std::thread::sleep(std::time::Duration::from_millis(100));
}
```

### 4. Содержимое файла `Cargo.toml` (конфигурация проекта)
```toml
[package]
name = "rust-app"
version = "0.1.0"
edition = "2021"

# Явно указываем имя бинарника, чтобы Dockerfile точно знал, что копировать
[[bin]]
name = "rust-app"
path = "src/main.rs"

[profile.release]
opt-level = "z"     # Оптимизация под размер
lto = true          # Link Time Optimization
strip = true        # Убираем символы отладки — бинарник меньше
```

### 5. Содержимое файла `.dockerignore` (блэе лист проекта)
```text
target/
.git/
.gitignore
Dockerfile
.dockerignore
*.md
```


### 6. Сборка и запуск

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

### 7 Зайти в контейнер

```shell
docker run -it --rm --entrypoint sh rust-app
```
Запустить программу на Rust:
```shell
./rust-app
```
выйти из контейнера
```shell
exit
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
