## Dockerfile. Приложение на C++ и FLTK

**FLTK** (Fast Light Toolkit) — кросс‑платформенная библиотека с открытым исходным кодом для построения графических пользовательских интерфейсов (GUI) на **C++**

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
cpp-fltk/
├── Dockerfile
├── main.cpp
└── CMakeLists.txt
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p cpp-fltk && touch cpp-fltk/Dockerfile cpp-fltk/main.cpp cpp-fltk/CMakeLists.txt && cd cpp-fltk
```

### 2. Содержимое файла `main.cpp`
```cpp
#include <FL/Fl.H>
#include <FL/Fl_Window.H>
#include <FL/Fl_Button.H>

int main(int argc, char **argv) {
    // Создаём окно размером 300x180 пикселей
    Fl_Window *window = new Fl_Window(300, 180, "Привет из Docker!");
    // Создаём кнопку и размещаем её в окне
    Fl_Button *button = new Fl_Button(80, 60, 140, 40, "Нажми меня!");
    // Завершаем добавление виджетов в окно
    window->end();
    // Показываем окно
    window->show(argc, argv);
    // Запускаем главный цикл обработки событий
    return Fl::run();
}
```

### 3. Содержимое файла `CMakeLists.txt`
```cmake
cmake_minimum_required(VERSION 3.10)
project(FLTKDockerDemo)
set(CMAKE_CXX_STANDARD 11)
# Указываем CMake использовать современные GLVND библиотеки OpenGL
cmake_policy(SET CMP0072 NEW)
find_package(FLTK REQUIRED)
include_directories(${FLTK_INCLUDE_DIRS})
add_executable(fltk_demo main.cpp)
target_link_libraries(fltk_demo ${FLTK_LIBRARIES})
```

### 4. Содержимое файла Dockerfile
```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
# Устанавливаем все необходимые пакеты
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    libx11-dev \
    libxft-dev \
    libxext-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxrender-dev \
    libxfixes-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    pkg-config \
    libfltk1.3-dev \
    fluid \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY main.cpp CMakeLists.txt ./
RUN mkdir build && cd build && \
    cmake .. && \
    make
CMD ["./build/fltk_demo"]
```

### 5. Сборка и запуск

В командной строке, находясь в папке `cpp-fltk`, выполнить:
```shell
docker build -t fltk-demo .
```

Создание и запуск контейнера в **Windows 10** (сборка 22000 и выше) или 11 в **PowerShell**
```shell
docker run -it --rm `
  -v /run/desktop/mnt/host/wslg/.X11-unix:/tmp/.X11-unix `
  -v /run/desktop/mnt/host/wslg:/mnt/wslg `
  -e DISPLAY=:0 `
  -e WAYLAND_DISPLAY=wayland-0 `
  -e XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir `
  fltk-demo
```

Создание и запуск контейнера в **Linux/WSL 2.0/Mac**
```shell
xhost +local:docker
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  fltk-demo
```

### 6. Войти в контейнер для исследования
```shell
docker run -it --entrypoint bash fltk-demo
```
выйти из контейнера:
```shell
exit
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
