## Dockerfile. Статический сайт на веб-сервере Nginx

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

Структура проекта:
```
my-website/
├── Dockerfile
└── index.html
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p my-website && touch my-website/Dockerfile my-website/index.html && cd my-website
```

Файл `index.html`:

или
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Мой сайт в Docker</title>
</head>
<body>
    <h1>Привет из контейнера! 🐳</h1>
    <p>Здесь может быть любой русский текст.</p>
</body>
</html>
```


Файл `Dockerfile`:
```dockerfile
# Используем официальный легковесный образ Nginx
FROM nginx:alpine
# Копируем наш HTML-файл в стандартную директорию Nginx
COPY index.html /usr/share/nginx/html/index.html
# Открываем порт (документация)
EXPOSE 80
```

В командной строке, находясь в папке `my-website`, выполнить:
```shell
docker build -t my-site .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run -d -p 8081:80 --name my-site -v "$(pwd)":/usr/share/nginx/html my-site
```

Пояснение:
* `-v "$(pwd)":/usr/share/nginx/html` — монтирует вашу текущую папку (где лежит `index.html`) в директорию, откуда **Nginx** берёт файлы.
* `$(pwd)` в **Linux/macOS/Git Bash**; в **PowerShell** используйте `${PWD}`.

Теперь любые изменения в `index.html` на хосте мгновенно отобразятся на сайте (потребуется обновить страницу в браузере).

[Откройте в браузере http://localhost:8081 для проверки](http://localhost:8081)

![Скрин работы приложения в браузере](/content/Docker/Dockerfile/img/nginx.png)

Для изменения содержимого веб-страницы просто отредактируйте локальный `index.html` и обновите веб-страницу в браузере без перезапуска Docker-контейнера.

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
