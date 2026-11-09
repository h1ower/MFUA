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