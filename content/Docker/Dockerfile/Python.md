## Dockerfile. Простое приложение на Python

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
my-python-app/
├── Dockerfile
└── app.py
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p my-python-app && touch my-python-app/Dockerfile my-python-app/app.py && cd my-python-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# Используем официальный образ Python 3 (slim-версия для меньшего размера)
FROM python:3-slim
# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /app
# Копируем файл приложения в контейнер
COPY app.py .
# Запускаем приложение
CMD ["python", "app.py"]
```

### 3. Содержимое файла `app.py`
```python
print("Hello from Python in Docker! 🐍")
```

### 4. Сборка и запуск

В командной строке, находясь в папке `my-python-app`, выполнить:
```shell
docker build -t my-python-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run --rm my-python-app
```

> Флаг `--rm` автоматически удаляет контейнер после остановки

Если всё прошло успешно, вы увидите вывод: `Hello from Python in Docker! 🐍`