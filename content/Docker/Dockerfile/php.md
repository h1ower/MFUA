## Dockerfile. PHP

**PHP** — серверный скриптовый язык программирования общего назначения, созданный для разработки веб‑приложений. Код на PHP выполняется на сервере, а результат (обычно HTML) передаётся в браузер клиента

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
php-docker/
├── Dockerfile
└── src/
    └── index.php
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p php-docker/src && touch php-docker/Dockerfile php-docker/src/index.php && cd php-docker
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# Используем официальный образ PHP с Apache
FROM php:8.2-apache
# Устанавливаем дополнительные расширения PHP (опционально)
RUN docker-php-ext-install pdo_mysql mysqli
# Копируем исходный код приложения в стандартную директорию Apache
COPY src/ /var/www/html/
# Устанавливаем рабочую директорию
WORKDIR /var/www/html
# Указываем, что контейнер слушает порт 80
EXPOSE 80
# Apache запускается автоматически (CMD уже есть в базовом образе)
```

### 3. Содержимое файла приложения на PHP `src/index.php`
```php
<!DOCTYPE html>
<html>
<head>
    <title>PHP в Docker</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial; margin: 40px; line-height: 1.6; }
        .info { background: #f0f0f0; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Привет из PHP в Docker! 🐳</h1>
    <div class="info">
        <h3>Информация о PHP:</h3>
        <?php
        echo "<p>Версия PHP: " . phpversion() . "</p>";
        echo "<p>Загруженные расширения: " . implode(', ', get_loaded_extensions()) . "</p>";
        ?>
    </div>
</body>
</html>
```

### 4. Сборка и запуск

В командной строке, находясь в папке `php-docker`, выполнить:
```shell
docker build -t php-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run -d -p 8081:80 --name my-php-app php-app
```

### 5. Проверка работы

[Откройте браузер и перейдите по адресу http://localhost:8081](http://localhost:8081)

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
