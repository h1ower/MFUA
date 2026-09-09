## Dockerfile. Flask+Python (мини-проект)

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

Простой `Dockerfile` для небольшого веб-приложения на **Python** с использованием **Flask**

- **Dockerfile** - рецепт приготовления Docker-образа
- **Flask** — микрофреймворк для создания веб-приложений на языке программирования **Python**

### 1. Структура проекта
```
simple_flask_app/
├── app.py
├── Dockerfile
└── requirements.txt
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p simple_flask_app && touch simple_flask_app/app.py simple_flask_app/requirements.txt simple_flask_app/Dockerfile simple_flask_app/.dockerignore && cd simple_flask_app
```

Общая структура проета должна выглядеть так:
```shell
simple_flask_app/
├── app.py              # простое Flask-приложение
├── requirements.txt    # список зависимостей Python
└── Dockerfile          # инструкции для сборки образа
└── .dockerignore       # чтобы исключить ненужные файлы сборки
```

### 2. Содержимое файла  `requirements.txt`:
```
Flask==3.0.0
```

### 3. Содержимое файла `Dockerfile`:
```dockerfile
# Базовый образ – официальный легковесный Python
FROM python:3.11-slim
# Устанавливаем рабочую директорию внутри контейнера
WORKDIR /app
# Копируем файл с зависимостями сначала (используем кэш слоёв)
COPY requirements.txt .
# Устанавливаем зависимости
RUN pip install --no-cache-dir -r requirements.txt
# Копируем остальные файлы проекта
COPY . .
# Указываем, какой порт будет слушать приложение внутри контейнера
EXPOSE 5000
# Команда для запуска приложения
CMD ["python", "app.py"]
```

### 4. Содержимое файла `.dockerignore`
```shell
__pycache__
*.pyc
.git
.env
```

### 5. Содержимое файла app.py
```py
from flask import Flask

# Создаём экземпляр приложения
app = Flask(__name__)

# Определяем маршрут для главной страницы
@app.route('/')
def hello():
    return "Hello, Docker! Привет из Flask!"

# Эндпоинт для проверки работоспособности (healthcheck)
@app.route('/health')
def health():
    return {"status": "healthy"}, 200

# Запускаем приложение, если файл выполняется напрямую
if __name__ == '__main__':
    # Важно: слушаем на всех интерфейсах (0.0.0.0), чтобы контейнер был доступен снаружи
    app.run(host='0.0.0.0', port=5000, debug=True)
```

### 5. Сборка образа

В командной строке, находясь в папке `simple_flask_app`, выполнить:
```shell
docker build -t my-flask-app .
```
> Флаг `-t` задает имя образа

### 6. Создание и запуск контейнера
```shell
docker run -d --name my-running-app -p 8082:5000 my-flask-app
```

### 7. Проверка работы

[Откройте браузер и перейдите по адресу http://localhost:8082](http://localhost:8082)

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
