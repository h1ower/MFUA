## Dockerfile. Wow - консольное псевдографисеское приложение на C++ и FTXUI

**FTXUI** — это библиотека для создания терминальных интерфейсов

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
ftxui-wow/
├── Dockerfile
├── main.cpp
└── CMakeLists.txt
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p ftxui-wow && touch ftxui-wow/Dockerfile ftxui-wow/main.cpp ftxui-wow/CMakeLists.txt && cd ftxui-wow
```

### 2. Содержимое файла `main.cpp` (приложения с меню)
```cpp
#include <chrono>
#include <thread>
#include <random>
#include <ftxui/component/captured_mouse.hpp>
#include <ftxui/component/component.hpp>
#include <ftxui/component/component_options.hpp>
#include <ftxui/component/screen_interactive.hpp>
#include <ftxui/dom/elements.hpp>

using namespace ftxui;
using namespace std::chrono_literals;
int main() {
  auto screen = ScreenInteractive::TerminalOutput();
  float value = 0.5f;
  bool increasing = true;
  std::thread update([&] {
    while (true) {
      std::this_thread::sleep_for(50ms);
      if (increasing) {
        value += 0.01f;
        if (value > 1.0f) increasing = false;
      } else {
        value -= 0.01f;
        if (value < 0.0f) increasing = true;
      }
      screen.Post([&] {});
    }
  });
  auto quit_button = Button("Exit", screen.ExitLoopClosure(), ButtonOption::Animated());
  auto component = Renderer(quit_button, [&] {
    return vbox({
             text("Hello from FTXUI!") | bold | color(Color::Cyan),
             separator(),
             hbox({
               text("Gauge:"),
               gauge(value) | size(WIDTH, EQUAL, 30) | color(Color::Green),
             }),
             separator(),
             quit_button->Render(),
           }) | border;
  });
  screen.Loop(component);
  update.detach();
  return 0;
}
```

### 3. Содержимое файла `CMakeLists.txt`
```cmake
cmake_minimum_required(VERSION 3.10)
project(ftxui_wow)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
include(FetchContent)
FetchContent_Declare(ftxui
  GIT_REPOSITORY https://github.com/ArthurSonzogni/FTXUI.git
  GIT_TAG v5.0.0
)
FetchContent_MakeAvailable(ftxui)
add_executable(ftxui_wow main.cpp)
target_link_libraries(ftxui_wow PRIVATE ftxui::component ftxui::dom ftxui::screen)
```

### 4. Содержимое файла Dockerfile
```dockerfile
FROM ubuntu:22.04 AS build
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY main.cpp CMakeLists.txt ./
RUN mkdir build && cd build && \
    cmake .. && \
    make
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/build/ftxui_wow /usr/local/bin/ftxui_wow
CMD ["ftxui_wow"]
```

### 5. Сборка и запуск

В командной строке, находясь в папке `ftxui-wow`, выполнить:
```shell
docker build -t ftxui-wow .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера
```shell
docker run -it --rm ftxui-wow
```

### 6. Войти в контейнер для исследования
```shell
docker run -it --entrypoint bash ftxui-wow
```
выйти из контейнера:
```shell
exit
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
