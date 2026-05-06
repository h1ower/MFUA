## Dockerfile. Hello-world

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!


В каталоге для Docker-проектов создайте структуру проекта командой Bash:
```shell
mkdir -p hello-world && touch hello-world/Dockerfile && cd hello-world
```

Содержимое файла `Dockerfile`
```dockerfile
# Используем минимальный базовый образ Alpine Linux
FROM alpine:latest
# Команда, которая выполнится при запуске контейнера
CMD ["echo", "Привет, Docker! 🐳"]
```

В командной строке, находясь в папке `hello-world`, выполнить:
```shell
docker build -t hello-world .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run --rm hello-world
```

![Скриншот из командной строки](/content/img/docker_hello_world.png)

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
