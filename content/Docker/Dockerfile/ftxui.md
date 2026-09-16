## Dockerfile. Консольное приложение на C++ и FTXUI

**FTXUI** — это библиотека для создания терминальных интерфейсов

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
cpp-ftxui/
├── Dockerfile
├── main.cpp
└── CMakeLists.txt
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p cpp-ftxui && touch cpp-ftxui/Dockerfile cpp-ftxui/main.cpp cpp-ftxui/CMakeLists.txt && cd cpp-ftxui
```

### 2. Содержимое файла `main.cpp` (приложения с меню)
```cpp
#include <functional>
#include <iostream>
#include <string>
#include <vector>
#include <ftxui/component/captured_mouse.hpp>
#include <ftxui/component/component.hpp>
#include <ftxui/component/component_options.hpp>
#include <ftxui/component/screen_interactive.hpp>

int main() {
  using namespace ftxui;
  auto screen = ScreenInteractive::TerminalOutput();
  std::vector<std::string> entries = {
      "Файл",
      "Правка",
      "Вид",
      "Справка",
  };
  int selected = 0;
  MenuOption option;
  option.on_enter = screen.ExitLoopClosure();
  auto menu = Menu(&entries, &selected, option);
  screen.Loop(menu);
  std::cout << "Вы выбрали пункт " << selected + 1 << std::endl;
  return 0;
}
```

### 3. Содержимое файла `CMakeLists.txt`
```cmake
cmake_minimum_required(VERSION 3.10)
project(ftxui_demo)
# Указываем стандарт C++17 (FTXUI требует C++17)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Подключаем FetchContent для загрузки FTXUI
include(FetchContent)
FetchContent_Declare(ftxui
  GIT_REPOSITORY https://github.com/ArthurSonzogni/FTXUI.git
  GIT_TAG v5.0.0  # можно использовать последний тег
)
FetchContent_MakeAvailable(ftxui)
# Создаём исполняемый файл
add_executable(ftxui_demo main.cpp)
# Линкуем библиотеки FTXUI
target_link_libraries(ftxui_demo PRIVATE
  ftxui::component
  ftxui::dom
  ftxui::screen
)
```

### 4. Содержимое файла Dockerfile
```dockerfile
# ---- Этап 1: сборка ----
FROM ubuntu:22.04 AS build
# Устанавливаем необходимые пакеты для сборки
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*
# Создаём рабочую директорию
WORKDIR /app
# Копируем исходники
COPY main.cpp CMakeLists.txt ./
# Собираем проект
RUN mkdir build && cd build && \
    cmake .. && \
    make
# ---- Этап 2: финальный образ ----
FROM ubuntu:22.04
# Устанавливаем только необходимые рантайм-библиотеки
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
# Копируем собранный бинарник из этапа сборки
COPY --from=build /app/build/ftxui_demo /usr/local/bin/ftxui_demo
# Запускаем приложение
CMD ["ftxui_demo"]
```

### 5. Сборка и запуск

В командной строке, находясь в папке `cpp-ftxui`, выполнить:
```shell
docker build -t ftxui-demo .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера
```shell
docker run -it --rm ftxui-demo
```

### 6. Войти в контейнер для исследования
```shell
docker run -it --entrypoint bash ftxui-demo
```
выйти из контейнера:
```shell
exit
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
