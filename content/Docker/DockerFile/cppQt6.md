## Dockerfile. Qt6/C++ приложение

**Qt** — это кросс‑платформенный фреймворк для разработки программного обеспечения на языке **C++**.

> Для выполнения этого задания используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

- Выполнять это задание следует в **WSL** (вызвать **Ubuntu** из **Главного меню**)
- Если **WSL/Ubuntu** не установлен, установите по инструкции в главном [README.md - WSL 2.0](/README.md)
- Кроме **WSL/Ubuntu** в ваш **VS Code** надо установить расширение **WSL** по инструкции в главном [README.md - Минимальные настройки `VSCode`](/README.md)
- После установки расширенимя **WSL** в **VS Code**, вам необходимо закрыть его и открыть **VS Code** в **WSL/Ubuntu** командой `code .`

### 1. Структура проекта
```
qt6-docker-app/
├── CMakeLists.txt          # Скрипт сборки для CMake
├── main.cpp                # Исходный код приложения
└── Dockerfile              # Инструкция для создания образа
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p qt6-docker-app && touch qt6-docker-app/Dockerfile qt6-docker-app/main.cpp qt6-docker-app/CMakeLists.txt && cd qt6-docker-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
# Устанавливаем всё необходимое для сборки и запуска Qt6 GUI
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    qt6-base-dev \
    qt6-base-dev-tools \
    libgl1-mesa-dev \
    libxkbcommon-x11-0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xinerama0 \
    libxcb-cursor0 \
    libxcb-xkb1 \
    libxcb-util1 \
    libxkbcommon0 \
    libxkbcommon-x11-0 \
    libxcb-icccm4-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-shape0-dev \
    libxcb-xfixes0-dev \
    libxcb-xinerama0-dev \
    libxcb-cursor-dev \
    libxcb-xkb-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    mesa-utils \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY CMakeLists.txt main.cpp ./
RUN cmake -B build -S . -G Ninja && \
    cmake --build build --parallel
ENV QT_QPA_PLATFORM=xcb
CMD ["./build/qt6_app"]
```

### 3. Содержимое файла `CMakeLists.txt`
```cmake
cmake_minimum_required(VERSION 3.16)
project(Qt6DockerApp)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Widgets)

add_executable(qt6_app main.cpp)
target_link_libraries(qt6_app Qt6::Core Qt6::Widgets)
```

### 4. Содержимое файла `main.cpp` (простое Qt-приложение)
```cpp
#include <QApplication>
#include <QWidget>
#include <QVBoxLayout>
#include <QLabel>
#include <QPushButton>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    // Создаём главное окно
    QWidget window;
    window.setFixedSize(400, 200);
    window.setWindowTitle("Фиксированное окно с кнопкой");
    // Создаём вертикальный layout
    QVBoxLayout *layout = new QVBoxLayout(&window);
    // Добавляем текстовую метку
    QLabel *label = new QLabel("Привет из Docker-контейнера с Qt6!");
    label->setAlignment(Qt::AlignCenter);
    layout->addWidget(label);
    // Добавляем кнопку
    QPushButton *button = new QPushButton("Нажми меня");
    button->setFixedSize(120, 30); // необязательно: фиксированный размер кнопки
    layout->addWidget(button, 0, Qt::AlignCenter); // выравнивание по центру
    // Показываем окно
    window.show();
    return app.exec();
}
```

### 5. Сборка и запуск

В командной строке **VS Code+WSL**, находясь в папке `qt6-docker-app`, выполнить:
```shell
docker build -t qt6-app .
```

Создание и запуск контейнера для **Windows - WSLg/WSL (терминал Ubutnu)**
```shell
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  qt6-app
```

Создание и запуск контейнера для **macOS** (не проверял!)
```shell
xhost + 127.0.0.1
```
и
```shell
docker run -it --rm \
  -e DISPLAY=host.docker.internal:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  qt6-app
```

