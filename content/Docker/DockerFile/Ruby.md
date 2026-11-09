## Dockerfile. Приложение на Ruby

**Ruby** — высокоуровневый язык программирования

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
ruby-app/
├── Dockerfile
├── Gemfile
└── app.rb
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p ruby-app && touch ruby-app/Dockerfile ruby-app/Gemfile ruby-app/app.rb && cd ruby-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# ---- Базовый образ ----
FROM ruby:3.3-slim
# Устанавливаем необходимые системные пакеты для компиляции нативных гемов
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
# ---- Установка рабочей директории ----
WORKDIR /app
# ---- Копирование файла с зависимостями и их установка ----
# Копируем только Gemfile (не Gemfile.lock, если его нет)
COPY Gemfile ./
# Устанавливаем зависимости (гемы)
RUN bundle install
# ---- Копирование остального кода приложения ----
COPY . .
# ---- Запуск приложения ----
CMD ["ruby", "app.rb"]
```

### 3. Содержимое файла `Gemfile`
```Gemfile
source 'https://rubygems.org'
gem 'httparty'
```

### 4. Содержимое файла `app.rb`
```ruby
require 'httparty'

response = HTTParty.get('https://catfact.ninja/fact')
if response.success?
  fact = response.parsed_response['fact']
  puts "🐱 Случайный факт о котах: #{fact}"
else
  puts "😿 Не удалось получить факт."
end
```

### 5. Сборка и запуск

В командной строке, находясь в папке `ruby-app`, выполнить:
```shell
docker build -t ruby-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run -it --rm ruby-app
```

> Вы можете увидеть - 🐱 Случайный факт о котах: A cat's tail can contain up to 20,000 hairs.

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
