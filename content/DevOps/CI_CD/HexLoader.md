## CI/CD с приложением на Go (Fyne) - Hex Loader, с публикацией бинарников в GitHub Releases

Задачи:

1. При помощи нейросети создать с этими исходными файлами проект **CI/CD** для приложения **Hex Loader (Go+Fyne)** с публикацией бинарников в **GitHub Releases**;
2. После успешного **Workflow** оформить поэтапное **README.md** с демонстрацией скриншотов.
3. После успешных **Actions** создать `README.md` с описанием всех этапов разработки этого проекта со скриншотами (в т.ч. окна запущенного приложения)


Файл `main.go`:
```go
package main

import (
	"bytes"
	"fmt"
	"image/color"
	"os/exec"
	"os/user"
	"strings"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/storage"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

// BoardInfo хранит информацию о подключенной плате
type BoardInfo struct {
	Port string
	FQBN string
}

// myTheme — кастомная тема с увеличенным размером и убранной тенью
type myTheme struct {
	fyne.Theme
}

func (t myTheme) Size(name fyne.ThemeSizeName) float32 {
	switch name {
	case theme.SizeNameText:
		return 16
	case theme.SizeNamePadding:
		return 14
	default:
		return t.Theme.Size(name)
	}
}

func (t myTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNamePrimary:
		return color.NRGBA{R: 0x88, G: 0x88, B: 0x88, A: 0xFF}
	case theme.ColorNameBackground:
		return color.NRGBA{R: 0xE0, G: 0xE0, B: 0xE0, A: 0xFF}
	case theme.ColorNameShadow:
		return color.Transparent
	default:
		return t.Theme.Color(name, variant)
	}
}

// buttonWithBorder — кастомная кнопка с обводкой
type buttonWithBorder struct {
	widget.Button
}

func newButtonWithBorder(label string, onTap func()) *buttonWithBorder {
	btn := &buttonWithBorder{}
	btn.ExtendBaseWidget(btn)
	btn.Text = label
	btn.OnTapped = onTap
	return btn
}

func (b *buttonWithBorder) CreateRenderer() fyne.WidgetRenderer {
	return &buttonRenderer{btn: b}
}

// buttonRenderer — рендерер кнопки с обводкой
type buttonRenderer struct {
	btn       *buttonWithBorder
	label     *canvas.Text
	bg        *canvas.Rectangle
	border    *canvas.Rectangle
	objects   []fyne.CanvasObject
	container *fyne.Container
}

func (r *buttonRenderer) init() {
	if r.container != nil {
		return
	}
	r.label = canvas.NewText(r.btn.Text, theme.Color(theme.ColorNameForeground))
	r.label.Alignment = fyne.TextAlignCenter
	r.label.TextSize = theme.TextSize()

	r.bg = canvas.NewRectangle(theme.Color(theme.ColorNameButton))
	r.bg.CornerRadius = 8

	r.border = canvas.NewRectangle(color.Transparent)
	r.border.StrokeWidth = 2
	r.border.StrokeColor = color.NRGBA{R: 0x33, G: 0x33, B: 0x33, A: 0xFF}
	r.border.CornerRadius = 8

	r.container = container.NewStack(r.bg, r.border, r.label)
	r.objects = []fyne.CanvasObject{r.container}
}

func (r *buttonRenderer) Layout(size fyne.Size) {
	r.init()
	r.container.Resize(size)
}

func (r *buttonRenderer) MinSize() fyne.Size {
	r.init()
	minSize := r.container.MinSize()
	return fyne.NewSize(minSize.Width+40, minSize.Height+16)
}

func (r *buttonRenderer) Refresh() {
	r.init()
	r.label.Text = r.btn.Text
	r.label.Color = theme.Color(theme.ColorNameForeground)
	r.label.TextSize = theme.TextSize()

	if r.btn.Disabled() {
		r.bg.FillColor = theme.Color(theme.ColorNameDisabled)
		r.border.StrokeColor = color.NRGBA{R: 0x66, G: 0x66, B: 0x66, A: 0x80}
	} else {
		r.bg.FillColor = theme.Color(theme.ColorNameButton)
		r.border.StrokeColor = color.NRGBA{R: 0x33, G: 0x33, B: 0x33, A: 0xFF}
	}
	r.bg.CornerRadius = 8
	r.border.CornerRadius = 8

	r.label.Refresh()
	r.bg.Refresh()
	r.border.Refresh()
	canvas.Refresh(r.btn)
}

func (r *buttonRenderer) Objects() []fyne.CanvasObject {
	r.init()
	return r.objects
}

func (r *buttonRenderer) Destroy() {}

// showCustomInformation — кастомный информационный диалог с кнопкой с обводкой
func showCustomInformation(title, message string, w fyne.Window) {
	label := widget.NewLabel(message)
	label.Wrapping = fyne.TextWrapWord

	var d *dialog.CustomDialog

	d = dialog.NewCustom(title, "", container.NewVBox(
		label,
		container.NewCenter(newButtonWithBorder("OK", func() {
			if d != nil {
				d.Hide()
			}
		})),
	), w)
	d.Resize(fyne.NewSize(400, 200))
	d.Show()
}

// checkArduinoCLI проверяет, доступен ли arduino-cli в PATH
func checkArduinoCLI() error {
	_, err := exec.LookPath("arduino-cli")
	return err
}

// checkUserInGroup проверяет, состоит ли текущий пользователь в указанной группе
func checkUserInGroup(groupName string) (bool, error) {
	currentUser, err := user.Current()
	if err != nil {
		return false, err
	}

	cmd := exec.Command("groups", currentUser.Username)
	output, err := cmd.Output()
	if err != nil {
		return false, err
	}
	groups := strings.Fields(string(output))
	for _, g := range groups {
		if g == groupName {
			return true, nil
		}
	}
	return false, nil
}

// showPermissionWarning показывает предупреждение о правах
func showPermissionWarning(a fyne.App, w fyne.Window) {
	var d *dialog.CustomDialog

	label := widget.NewLabel(
		"⚠️ У вас нет прав для работы с последовательными портами.\n\n" +
			"Чтобы Hex Loader мог определять и прошивать платы,\n" +
			"добавьте пользователя в группу dialout:\n\n" +
			"  sudo usermod -a -G dialout $USER\n\n" +
			"После этого выйдите из системы и зайдите заново.\n\n" +
			"Вы всё равно можете использовать программу,\n" +
			"но порты могут не определяться.",
	)

	btnOk := newButtonWithBorder("Понятно", func() {
		if d != nil {
			d.Hide()
		}
	})

	content := container.NewVBox(label, btnOk)
	d = dialog.NewCustom("Внимание", "", content, w)
	d.Resize(fyne.NewSize(500, 300))
	d.Show()
}

// uploadWithProgress выполняет загрузку с отображением статуса
func uploadWithProgress(hexPath, portPath, fqbn string, statusLabel *widget.Label) error {
	result := make(chan error)

	go func() {
		fyne.Do(func() {
			statusLabel.SetText("⏳ Подождите, идёт загрузка...")
			statusLabel.Refresh()
		})

		time.Sleep(50 * time.Millisecond)

		cmd := exec.Command(
			"arduino-cli",
			"upload",
			"-p", portPath,
			"--fqbn", fqbn,
			"--input-file", hexPath,
		)
		var stderr bytes.Buffer
		cmd.Stderr = &stderr

		err := cmd.Run()
		if err != nil {
			result <- fmt.Errorf("ошибка загрузки: %v: %s", err, stderr.String())
			return
		}
		result <- nil
	}()

	err := <-result

	if err != nil {
		fyne.Do(func() {
			statusLabel.SetText("❌ Ошибка загрузки")
			statusLabel.Refresh()
		})
		return err
	}

	fyne.Do(func() {
		statusLabel.SetText("✅ Загрузка успешно завершена!")
		statusLabel.Refresh()
	})
	return nil
}

func main() {
	a := app.NewWithID("com.example.hexloader")
	a.Settings().SetTheme(&myTheme{theme.DefaultTheme()})

	w := a.NewWindow("Загрузчик HEX в Arduino")
	w.Resize(fyne.NewSize(700, 480))

	var hexPath string
	var portPath string
	var fqbn string

	// Получаем preferences для сохранения настроек
	prefs := a.Preferences()

	// Загружаем последний выбранный HEX файл из настроек
	lastHexPath := prefs.String("lastHexPath")
	if lastHexPath != "" {
		hexPath = lastHexPath
	}

	hexLabel := widget.NewLabel("Файл не выбран")
	if hexPath != "" {
		hexLabel.SetText(hexPath)
	}

	portLabel := widget.NewLabel("Порт не выбран")
	statusLabel := widget.NewLabel("Готов к работе")

	// --- ИКОНКА В ИНТЕРФЕЙСЕ ---
	iconImage := canvas.NewImageFromFile("icon.png")
	iconImage.FillMode = canvas.ImageFillContain
	iconImage.SetMinSize(fyne.NewSize(64, 64))
	iconImage.Resize(fyne.NewSize(64, 64))
	iconImage.Refresh()

	// Создаём заголовок
	title := canvas.NewText("Загрузчик HEX файлов в Arduino", color.NRGBA{R: 0x00, G: 0x00, B: 0x00, A: 0xFF})
	title.TextSize = 22
	title.TextStyle.Bold = true
	title.Alignment = fyne.TextAlignCenter

	// Собираем заголовок с иконкой
	header := container.NewVBox(
		container.NewCenter(iconImage),
		title,
	)

	// Кнопка выбора HEX с фильтром и сохранением пути
	btnSelectHex := newButtonWithBorder("📂 Выбрать HEX", func() {
		fileFilter := storage.NewExtensionFileFilter([]string{".hex"})
		fileDialog := dialog.NewFileOpen(func(reader fyne.URIReadCloser, err error) {
			if err != nil {
				dialog.ShowError(err, w)
				return
			}
			if reader == nil {
				return
			}
			defer reader.Close()
			hexPath = reader.URI().Path()
			hexLabel.SetText(hexPath)
			statusLabel.SetText("HEX файл выбран")

			// Сохраняем путь в preferences
			prefs.SetString("lastHexPath", hexPath)
		}, w)
		fileDialog.SetFilter(fileFilter)
		fileDialog.Show()
	})

	btnSelectPort := newButtonWithBorder("🔌 Выбрать порт", func() {
		boards, err := getAvailableBoards()
		if err != nil {
			dialog.ShowError(fmt.Errorf("не удалось получить список плат: %v", err), w)
			return
		}
		if len(boards) == 0 {
			// Используем кастомный диалог вместо dialog.ShowInformation
			showCustomInformation("Нет плат", "Подключенные Arduino платы не найдены.", w)
			return
		}

		if len(boards) == 1 {
			selectBoard(boards[0], &portPath, &fqbn, portLabel, statusLabel, w)
			return
		}

		items := make([]string, len(boards))
		for i, b := range boards {
			label := b.Port
			if b.FQBN != "" && strings.Count(b.FQBN, ":") >= 2 {
				label += " (" + b.FQBN + ")"
			} else {
				label += " (тип не определён)"
			}
			items[i] = label
		}
		selected := widget.NewSelect(items, func(s string) {
			port := strings.Split(s, " ")[0]
			for _, b := range boards {
				if b.Port == port {
					selectBoard(b, &portPath, &fqbn, portLabel, statusLabel, w)
					break
				}
			}
		})
		dialog.ShowCustom("Выберите плату", "OK", selected, w)
	})

	btnUpload := newButtonWithBorder("⬆️ Загрузить", func() {
		if hexPath == "" {
			showCustomInformation("Ошибка", "Сначала выберите HEX файл.", w)
			return
		}
		if portPath == "" {
			showCustomInformation("Ошибка", "Сначала выберите порт.", w)
			return
		}
		if fqbn == "" {
			showFQBNInputDialog(w, &fqbn, statusLabel)
			if fqbn == "" {
				return
			}
		}

		// Проверяем, установлено ли ядро
		cmd := exec.Command("arduino-cli", "core", "list")
		var out bytes.Buffer
		cmd.Stdout = &out
		cmd.Run()
		coreName := strings.Split(fqbn, ":")[0] + ":" + strings.Split(fqbn, ":")[1]
		if !strings.Contains(out.String(), coreName) {
			dialog.ShowError(fmt.Errorf("ядро %s не установлено. Установите его через arduino-cli или скопируйте папку packages", coreName), w)
			return
		}

		go func() {
			err := uploadWithProgress(hexPath, portPath, fqbn, statusLabel)
			if err != nil {
				fyne.Do(func() {
					dialog.ShowError(fmt.Errorf("ошибка загрузки: %v", err), w)
				})
			}
		}()
	})

	if err := checkArduinoCLI(); err != nil {
		btnSelectHex.Disable()
		btnSelectPort.Disable()
		btnUpload.Disable()
		statusLabel.SetText("❌ arduino-cli не найден")
	}

	inDialout, _ := checkUserInGroup("dialout")
	inUucp, _ := checkUserInGroup("uucp")
	if !inDialout && !inUucp {
		go func() {
			time.Sleep(500 * time.Millisecond)
			showPermissionWarning(a, w)
		}()
		statusLabel.SetText("⚠️ Нет прав на доступ к портам (нужна группа dialout)")
	}

	content := container.NewVBox(
		header, // Заголовок с иконкой
		widget.NewSeparator(),
		container.NewHBox(btnSelectHex, hexLabel),
		container.NewHBox(btnSelectPort, portLabel),
		widget.NewSeparator(),
		btnUpload,
		statusLabel,
	)

	w.SetContent(content)
	w.ShowAndRun()
}

func selectBoard(board BoardInfo, portPath *string, fqbn *string, portLabel *widget.Label, statusLabel *widget.Label, w fyne.Window) {
	*portPath = board.Port
	portLabel.SetText(board.Port)
	if board.FQBN != "" && strings.Count(board.FQBN, ":") >= 2 {
		*fqbn = board.FQBN
		portLabel.SetText(board.Port + " (" + board.FQBN + ")")
		statusLabel.SetText("Порт выбран: " + board.Port + " (" + board.FQBN + ")")
	} else {
		statusLabel.SetText("Тип платы не определён. Выберите FQBN.")
		showFQBNInputDialog(w, fqbn, statusLabel)
		if *fqbn != "" {
			portLabel.SetText(board.Port + " (" + *fqbn + ")")
			statusLabel.SetText("Порт выбран: " + board.Port + " (" + *fqbn + ")")
		} else {
			portLabel.SetText(board.Port + " (тип не выбран)")
			statusLabel.SetText("FQBN не выбран")
		}
	}
}

func showFQBNInputDialog(w fyne.Window, fqbn *string, statusLabel *widget.Label) {
	commonFQBNs := []string{
		"arduino:avr:uno",
		"arduino:avr:nano",
		"arduino:avr:mega",
		"arduino:avr:leonardo",
		"esp32:esp32:esp32",
		"esp8266:esp8266:generic",
	}

	// Создаём Select
	selectWidget := widget.NewSelect(commonFQBNs, func(s string) {
		*fqbn = s
		statusLabel.SetText("FQBN выбран: " + s)
	})

	// Создаём рамку (контур)
	border := canvas.NewRectangle(color.Transparent)
	border.StrokeWidth = 2
	border.StrokeColor = color.NRGBA{R: 0x33, G: 0x33, B: 0x33, A: 0xFF}
	border.CornerRadius = 8

	// Собираем Select с рамкой в стек (БЕЗ отступов)
	selectWithBorder := container.NewStack(
		border,
		selectWidget, // ← Прямо на рамку, без Padded
	)

	// Оборачиваем в контейнер с фиксированной шириной и высотой
	selectWrapper := container.NewHBox(
		selectWithBorder,
	)
	selectWrapper.Resize(fyne.NewSize(600, 80))

	// Создаём Entry для ручного ввода
	entry := widget.NewEntry()
	entry.SetPlaceHolder("Или введите свой FQBN вручную")
	entry.OnSubmitted = func(s string) {
		if s != "" {
			*fqbn = s
			statusLabel.SetText("FQBN введён: " + s)
		}
	}

	var dialogObj *dialog.CustomDialog

	okButton := newButtonWithBorder("✅ OK", func() {
		if *fqbn == "" && entry.Text != "" {
			*fqbn = entry.Text
			statusLabel.SetText("FQBN выбран: " + *fqbn)
		}
		if *fqbn == "" && len(commonFQBNs) > 0 {
			*fqbn = commonFQBNs[0]
			statusLabel.SetText("FQBN выбран: " + *fqbn)
		}
		if dialogObj != nil {
			dialogObj.Hide()
		}
	})

	content := container.NewVBox(
		widget.NewLabel("Выберите или введите FQBN для вашей платы:"),
		selectWrapper,
		widget.NewLabel("или"),
		entry,
		container.NewCenter(okButton),
	)

	dialogObj = dialog.NewCustom("Выбор FQBN", "", content, w)
	dialogObj.Resize(fyne.NewSize(600, 480))
	dialogObj.Show()
}

// getAvailableBoards возвращает список плат через текстовый парсинг
func getAvailableBoards() ([]BoardInfo, error) {
	cmd := exec.Command("arduino-cli", "board", "list")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return nil, fmt.Errorf("ошибка запуска arduino-cli: %v", err)
	}

	lines := strings.Split(out.String(), "\n")
	var boards []BoardInfo
	for _, line := range lines {
		if !strings.Contains(line, "/dev/") && !strings.Contains(line, "COM") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		port := fields[0]
		if !strings.HasPrefix(port, "/dev/") && !strings.HasPrefix(port, "COM") {
			continue
		}
		var fqbn string
		for _, field := range fields {
			if strings.Count(field, ":") >= 2 {
				fqbn = field
				break
			}
		}
		boards = append(boards, BoardInfo{Port: port, FQBN: fqbn})
	}
	return boards, nil
}

func uploadHex(hexPath, portPath, fqbn string) error {
	cmd := exec.Command(
		"arduino-cli",
		"upload",
		"-p", portPath,
		"--fqbn", fqbn,
		"--input-file", hexPath,
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		return fmt.Errorf("%v: %s", err, stderr.String())
	}
	return nil
}
```

Файл `go.sum`:
```go
fyne.io/fyne/v2 v2.8.0 h1:KNUdIk1eKsXSPy/wU6MdiR1hppAPvyzbjPbtJ8h6EUQ=
fyne.io/fyne/v2 v2.8.0/go.mod h1:tLJK7CVtUBOnMiSDR+J88t/quiGuEhwGs09tIVM1RXg=
fyne.io/systray v1.12.2 h1:Y8DZxgLHsVQt6rY9Zrkkg+j67S7vv/1F2viOWKPpVeA=
fyne.io/systray v1.12.2/go.mod h1:RVwqP9nYMo7h5zViCBHri2FgjXF7H2cub7MAq4NSoLs=
github.com/BurntSushi/toml v1.6.0 h1:dRaEfpa2VI55EwlIW72hMRHdWouJeRF7TPYhI+AUQjk=
github.com/BurntSushi/toml v1.6.0/go.mod h1:ukJfTF/6rtPPRCnwkur4qwRxa8vTRFBF0uk2lLoLwho=
github.com/FyshOS/fancyfs v0.0.1 h1:kgvm7VvwOMLkYTqSflplp62SlMVWQ2uAoHw9CXwXHYg=
github.com/FyshOS/fancyfs v0.0.1/go.mod h1:S5SHVz/5R72iCXOxCqdcyTPSlg3JxNd0gaHyGBSrY8A=
github.com/anthonynsimon/bild v0.14.0 h1:IFRkmKdNdqmexXHfEU7rPlAmdUZ8BDZEGtGHDnGWync=
github.com/anthonynsimon/bild v0.14.0/go.mod h1:hcvEAyBjTW69qkKJTfpcDQ83sSZHxwOunsseDfeQhUs=
github.com/clipperhouse/uax29/v2 v2.2.0 h1:ChwIKnQN3kcZteTXMgb1wztSgaU+ZemkgWdohwgs8tY=
github.com/clipperhouse/uax29/v2 v2.2.0/go.mod h1:EFJ2TJMRUaplDxHKj1qAEhCtQPW2tJSwu5BF98AuoVM=
github.com/davecgh/go-spew v1.1.1 h1:vj9j/u1bqnvCEfJOwUhtlOARqs3+rkHYY13jYWTU97c=
github.com/davecgh/go-spew v1.1.1/go.mod h1:J7Y8YcW2NihsgmVo/mv3lAwl/skON4iLHjSsI+c5H38=
github.com/felixge/fgprof v0.9.3 h1:VvyZxILNuCiUCSXtPtYmmtGvb65nqXh2QFWc0Wpf2/g=
github.com/felixge/fgprof v0.9.3/go.mod h1:RdbpDgzqYVh/T9fPELJyV7EYJuHB55UTEULNun8eiPw=
github.com/fredbi/uri v1.1.1 h1:xZHJC08GZNIUhbP5ImTHnt5Ya0T8FI2VAwI/37kh2Ko=
github.com/fredbi/uri v1.1.1/go.mod h1:4+DZQ5zBjEwQCDmXW5JdIjz0PUA+yJbvtBv+u+adr5o=
github.com/fsnotify/fsnotify v1.9.0 h1:2Ml+OJNzbYCTzsxtv8vKSFD9PbJjmhYF14k/jKC7S9k=
github.com/fsnotify/fsnotify v1.9.0/go.mod h1:8jBTzvmWwFyi3Pb8djgCCO5IBqzKJ/Jwo8TRcHyHii0=
github.com/fyne-io/gl-js v0.2.1-0.20260315212741-029c47fd27e8 h1:0kdPD/GEntpWmZEK5Zu/xE6Tr37jYCVDf9QP8lA/QK8=
github.com/fyne-io/gl-js v0.2.1-0.20260315212741-029c47fd27e8/go.mod h1:ZcepK8vmOYLu96JoxbCKJy2ybr+g1pTnaBDdl7c3ajI=
github.com/fyne-io/glfw-js v0.4.0 h1:I9hREBeFyI10cNIqbMKYb1PRidyPDgwob8o2la9SfQo=
github.com/fyne-io/glfw-js v0.4.0/go.mod h1:SDchsFZh4n7nVuBoiowOhOgIBdz+qUQVeC1w9fe2yVU=
github.com/fyne-io/image v0.1.1 h1:WH0z4H7qfvNUw5l4p3bC1q70sa5+YWVt6HCj7y4VNyA=
github.com/fyne-io/image v0.1.1/go.mod h1:xrfYBh6yspc+KjkgdZU/ifUC9sPA5Iv7WYUBzQKK7JM=
github.com/fyne-io/oksvg v0.2.0 h1:mxcGU2dx6nwjJsSA9PCYZDuoAcsZ/OuJlvg/Q9Njfo8=
github.com/fyne-io/oksvg v0.2.0/go.mod h1:dJ9oEkPiWhnTFNCmRgEze+YNprJF7YRbpjgpWS4kzoI=
github.com/go-gl/gl v0.0.0-20260331235117-4566fea9a276 h1:IO5P06Pcj9K04d+l4nrf3c2U56+dAotIFG6u4P1wAHI=
github.com/go-gl/gl v0.0.0-20260331235117-4566fea9a276/go.mod h1:9YTyiznxEY1fVinfM7RvRcjRHbw2xLBJ3AAGIT0I4Nw=
github.com/go-gl/glfw/v3.4/glfw v0.1.0-pre.1.0.20260707082822-2a407d02d01a h1:HWK0MBggT/T6YH7VffE10xBIhqeTq8JzIUPJXrRy87g=
github.com/go-gl/glfw/v3.4/glfw v0.1.0-pre.1.0.20260707082822-2a407d02d01a/go.mod h1:T5Dn0JwIJOX1euPZ/iT4tq6nFYtmukjcYa7937HuYK8=
github.com/go-text/render v0.2.1 h1:qwHhxqGUjjg4L0XyJWj7M7bpY75NZM+kBpv2Yfw5mcg=
github.com/go-text/render v0.2.1/go.mod h1:HCCAq8MUlm/WRcXshBb4K/n+IkjeXQ1c2Ba+yICSm0A=
github.com/go-text/typesetting v0.3.4 h1:YYurUOtEb9kGSOz4uE3k4OpBGsp1dDL8+fjCeaFamAU=
github.com/go-text/typesetting v0.3.4/go.mod h1:4qZCQphq4KSgGTAeI0uMEkVbROgfah8BuyF5LRYr7XY=
github.com/go-text/typesetting-utils v0.0.0-20260223113751-2d88ac90dae3 h1:drBZzMgdYPbmyXqOto4YhhJGrFIQCX94FpR4MzTCsos=
github.com/go-text/typesetting-utils v0.0.0-20260223113751-2d88ac90dae3/go.mod h1:3/62I4La/HBRX9TcTpBj4eipLiwzf+vhI+7whTc9V7o=
github.com/godbus/dbus/v5 v5.2.2 h1:TUR3TgtSVDmjiXOgAAyaZbYmIeP3DPkld3jgKGV8mXQ=
github.com/godbus/dbus/v5 v5.2.2/go.mod h1:3AAv2+hPq5rdnr5txxxRwiGjPXamgoIHgz9FPBfOp3c=
github.com/google/pprof v0.0.0-20211214055906-6f57359322fd h1:1FjCyPC+syAzJ5/2S8fqdZK1R22vvA0J7JZKcuOIQ7Y=
github.com/google/pprof v0.0.0-20211214055906-6f57359322fd/go.mod h1:KgnwoLYCZ8IQu3XUZ8Nc/bM9CCZFOyjUNOSygVozoDg=
github.com/hack-pad/go-indexeddb v0.3.2 h1:DTqeJJYc1usa45Q5r52t01KhvlSN02+Oq+tQbSBI91A=
github.com/hack-pad/go-indexeddb v0.3.2/go.mod h1:QvfTevpDVlkfomY498LhstjwbPW6QC4VC/lxYb0Kom0=
github.com/hack-pad/safejs v0.1.0 h1:qPS6vjreAqh2amUqj4WNG1zIw7qlRQJ9K10eDKMCnE8=
github.com/hack-pad/safejs v0.1.0/go.mod h1:HdS+bKF1NrE72VoXZeWzxFOVQVUSqZJAG0xNCnb+Tio=
github.com/jeandeaual/go-locale v0.0.0-20250612000132-0ef82f21eade h1:FmusiCI1wHw+XQbvL9M+1r/C3SPqKrmBaIOYwVfQoDE=
github.com/jeandeaual/go-locale v0.0.0-20250612000132-0ef82f21eade/go.mod h1:ZDXo8KHryOWSIqnsb/CiDq7hQUYryCgdVnxbj8tDG7o=
github.com/jsummers/gobmp v0.0.0-20230614200233-a9de23ed2e25 h1:YLvr1eE6cdCqjOe972w/cYF+FjW34v27+9Vo5106B4M=
github.com/jsummers/gobmp v0.0.0-20230614200233-a9de23ed2e25/go.mod h1:kLgvv7o6UM+0QSf0QjAse3wReFDsb9qbZJdfexWlrQw=
github.com/kr/text v0.2.0 h1:5Nx0Ya0ZqY2ygV366QzturHI13Jq95ApcVaJBhpS+AY=
github.com/kr/text v0.2.0/go.mod h1:eLer722TekiGuMkidMxC/pM04lWEeraHUUmBw8l2grE=
github.com/mattn/go-runewidth v0.0.24 h1:cpokDiIn0MGnhdHwuWnJBITySJ20QyNGnY2kR/ay2DU=
github.com/mattn/go-runewidth v0.0.24/go.mod h1:XBkDxAl56ILZc9knddidhrOlY5R/pDhgLpndooCuJAs=
github.com/nfnt/resize v0.0.0-20180221191011-83c6a9932646 h1:zYyBkD/k9seD2A7fsi6Oo2LfFZAehjjQMERAvZLEDnQ=
github.com/nfnt/resize v0.0.0-20180221191011-83c6a9932646/go.mod h1:jpp1/29i3P1S/RLdc7JQKbRpFeM1dOBd8T9ki5s+AY8=
github.com/nicksnyder/go-i18n/v2 v2.5.1 h1:IxtPxYsR9Gp60cGXjfuR/llTqV8aYMsC472zD0D1vHk=
github.com/nicksnyder/go-i18n/v2 v2.5.1/go.mod h1:DrhgsSDZxoAfvVrBVLXoxZn/pN5TXqaDbq7ju94viiQ=
github.com/niemeyer/pretty v0.0.0-20200227124842-a10e7caefd8e h1:fD57ERR4JtEqsWbfPhv4DMiApHyliiK5xCTNVSPiaAs=
github.com/niemeyer/pretty v0.0.0-20200227124842-a10e7caefd8e/go.mod h1:zD1mROLANZcx1PVRCS0qkT7pwLkGfwJo4zjcN/Tysno=
github.com/pkg/profile v1.7.0 h1:hnbDkaNWPCLMO9wGLdBFTIZvzDrDfBM2072E1S9gJkA=
github.com/pkg/profile v1.7.0/go.mod h1:8Uer0jas47ZQMJ7VD+OHknK4YDY07LPUC6dEvqDjvNo=
github.com/pmezard/go-difflib v1.0.0 h1:4DBwDE0NGyQoBHbLQYPwSUPoCMWR5BEzIk/f1lZbAQM=
github.com/pmezard/go-difflib v1.0.0/go.mod h1:iKH77koFhYxTK1pcRnkKkqfTogsbg7gZNVY4sRDYZ/4=
github.com/rymdport/portal v0.4.2 h1:7jKRSemwlTyVHHrTGgQg7gmNPJs88xkbKcIL3NlcmSU=
github.com/rymdport/portal v0.4.2/go.mod h1:kFF4jslnJ8pD5uCi17brj/ODlfIidOxlgUDTO5ncnC4=
github.com/srwiley/oksvg v0.0.0-20221011165216-be6e8873101c h1:km8GpoQut05eY3GiYWEedbTT0qnSxrCjsVbb7yKY1KE=
github.com/srwiley/oksvg v0.0.0-20221011165216-be6e8873101c/go.mod h1:cNQ3dwVJtS5Hmnjxy6AgTPd0Inb3pW05ftPSX7NZO7Q=
github.com/srwiley/rasterx v0.0.0-20220730225603-2ab79fcdd4ef h1:Ch6Q+AZUxDBCVqdkI8FSpFyZDtCVBc2VmejdNrm5rRQ=
github.com/srwiley/rasterx v0.0.0-20220730225603-2ab79fcdd4ef/go.mod h1:nXTWP6+gD5+LUJ8krVhhoeHjvHTutPxMYl5SvkcnJNE=
github.com/stretchr/testify v1.11.1 h1:7s2iGBzp5EwR7/aIZr8ao5+dra3wiQyKjjFuvgVKu7U=
github.com/stretchr/testify v1.11.1/go.mod h1:wZwfW3scLgRK+23gO65QZefKpKQRnfz6sD981Nm4B6U=
github.com/yuin/goldmark v1.8.2 h1:kEGpgqJXdgbkhcOgBxkC0X0PmoPG1ZyoZ117rDVp4zE=
github.com/yuin/goldmark v1.8.2/go.mod h1:ip/1k0VRfGynBgxOz0yCqHrbZXhcjxyuS66Brc7iBKg=
golang.org/x/image v0.24.0 h1:AN7zRgVsbvmTfNyqIbbOraYL8mSwcKncEj8ofjgzcMQ=
golang.org/x/image v0.24.0/go.mod h1:4b/ITuLfqYq1hqZcjofwctIhi7sZh2WaCjvsBNjjya8=
golang.org/x/net v0.35.0 h1:T5GQRQb2y08kTAByq9L4/bz8cipCdA8FbRTXewonqY8=
golang.org/x/net v0.35.0/go.mod h1:EglIi67kWsHKlRzzVMUD93VMSWGFOMSZgxFjparz1Qk=
golang.org/x/sys v0.30.0 h1:QjkSwP/36a20jFYWkSue1YwXzLmsV5Gfq7Eiy72C1uc=
golang.org/x/sys v0.30.0/go.mod h1:/VUhepiaJMQUp4+oa/7Zr1D23ma6VTLIYjOOTFZPUcA=
golang.org/x/text v0.22.0 h1:bofq7m3/HAFvbF51jz3Q9wLg3jkvSPuiZu/pD1XwgtM=
golang.org/x/text v0.22.0/go.mod h1:YRoo4H8PVmsu+E3Ou7cqLVH8oXWIHVoX0jqUWALQhfY=
gopkg.in/check.v1 v0.0.0-20161208181325-20d25e280405/go.mod h1:Co6ibVJAznAaIkqp8huTwlJQCZ016jof/cbN4VW5Yz0=
gopkg.in/check.v1 v1.0.0-20200227125254-8fa46927fb4f h1:BLraFXnmrev5lT+xlilqcH8XK9/i0At2xKjWk4p6zsU=
gopkg.in/check.v1 v1.0.0-20200227125254-8fa46927fb4f/go.mod h1:Co6ibVJAznAaIkqp8huTwlJQCZ016jof/cbN4VW5Yz0=
gopkg.in/yaml.v3 v3.0.1 h1:fxVm/GzAzEWqLHuvctI91KS9hhNmmWOoWu0XTYJS7CA=
gopkg.in/yaml.v3 v3.0.1/go.mod h1:K4uyk7z7BCEPqu6E+C64Yfv1cQ7kz7rIZviUmN+EgEM=
```

> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!