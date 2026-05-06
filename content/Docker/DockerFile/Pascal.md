## Dockerfile. Приложение на Pascal

**Pascal** — это процедурный язык программирования, созданный в 1970 году. Изначально разрабатывался как учебный язык для обучения структурному программированию.

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
pascal-app/
├── Dockerfile
└── hello.pas # исходный код на Pascal
```
В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p pascal-app && touch pascal-app/Dockerfile pascal-app/hello.pas && cd pascal-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# Используем готовый образ с Free Pascal
FROM primeimages/freepascal:3.2.2
WORKDIR /app
# Копируем исходный код
COPY hello.pas .
# Компилируем
RUN fpc hello.pas
# Запускаем
CMD ["./hello"]
```

### 3. Содержимое файла `hello.pas`
```pascal
program Hello;
begin
  Writeln('Hello from Pascal in Docker! 🐳');
end.
```

### 4. Сборка и запуск

В командной строке, находясь в папке `pascal-app`, выполнить:
```shell
docker build -t pascal-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run --rm pascal-app
```

> Вы можете увидеть: `Hello from Pascal in Docker! 🐳`

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
