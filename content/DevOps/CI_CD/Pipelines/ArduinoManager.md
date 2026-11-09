## CI/CD с приложением на Go (Fyne) - Arduino Manager GUI, с публикацией бинарников в GitHub Releases

Задачи:

1. При помощи нейросети создать с этими исходными файлами проект **CI/CD** для приложения **Arduino Manager GUI (Go+Fyne)** с публикацией бинарников в **GitHub Releases**
2. После успешного **Workflow** оформить поэтапное **README.md** с демонстрацией скриншотов
3. После успешных **Actions** создать `README.md` с описанием всех этапов разработки этого проекта со скриншотами (в т.ч. окна запущенного приложения)

Файл `main.go`:
```go
package main

import (
	"archive/zip"
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

const (
	appID      = "local.arduino.manager.gui"
	appTitle   = "Arduino Manager"
	configName = ".arduino-manager.conf"
)

type Repo struct {
	FullName      string `json:"full_name"`
	Name          string `json:"name"`
	Description   string `json:"description"`
	Stars         int    `json:"stargazers_count"`
	HTMLURL       string `json:"html_url"`
	CloneURL      string `json:"clone_url"`
	DefaultBranch string `json:"default_branch"`
}

type Tag struct {
	Name string `json:"name"`
}

type IndexVersion struct {
	Version string `json:"version"`
	URL     string `json:"url"`
}

type IndexLibrary struct {
	Name     string         `json:"name"`
	Version  string         `json:"version"`
	URL      string         `json:"url"`
	Sentence string         `json:"sentence"`
	Versions []IndexVersion `json:"-"`
}

type LibraryIndex struct {
	Libraries []IndexLibrary `json:"libraries"`
}

type SearchItem struct {
	Repo        *Repo
	Library     *IndexLibrary
	Description string
	Kind        string
}

type Core struct {
	Label  string
	Repo   string
	Vendor string
	Arch   string
	Desc   string
}

var popularCores = []Core{
	{Label: "ESP8266", Repo: "esp8266/Arduino", Vendor: "esp8266", Arch: "esp8266", Desc: "NodeMCU, Wemos D1 mini, generic ESP8266"},
	{Label: "ESP32", Repo: "espressif/arduino-esp32", Vendor: "espressif", Arch: "esp32", Desc: "ESP32, ESP32-S2/S3/C3"},
	{Label: "RP2040 (Pico)", Repo: "arduino/ArduinoCore-mbed", Vendor: "arduino", Arch: "mbed", Desc: "Raspberry Pi Pico, Nano RP2040 Connect"},
	{Label: "STM32", Repo: "stm32duino/Arduino_Core_STM32", Vendor: "stm32duino", Arch: "stm32", Desc: "STM32F0-F7 (Blue Pill etc.)"},
	{Label: "AVR", Repo: "arduino/ArduinoCore-avr", Vendor: "arduino", Arch: "avr", Desc: "Uno, Mega, Nano, Leonardo"},
	{Label: "megaAVR", Repo: "arduino/ArduinoCore-megaavr", Vendor: "arduino", Arch: "megaavr", Desc: "Uno WiFi Rev2, Nano Every"},
	{Label: "SAMD", Repo: "arduino/ArduinoCore-samd", Vendor: "arduino", Arch: "samd", Desc: "MKR series, Zero, Nano 33 IoT"},
	{Label: "nRF52840", Repo: "arduino/ArduinoCore-nRF528x-mbedos", Vendor: "arduino", Arch: "nrf52840", Desc: "Nano 33 BLE / BLE Sense"},
	{Label: "Renesas", Repo: "arduino/ArduinoCore-renesas", Vendor: "arduino", Arch: "renesas", Desc: "Uno R4, Portenta C33"},
	{Label: "ATtiny", Repo: "SpenceKonde/ATTinyCore", Vendor: "ATTinyCore", Arch: "avr", Desc: "ATtiny13/25/45/85/24/44/84"},
	{Label: "megaTiny", Repo: "SpenceKonde/megaTinyCore", Vendor: "megaTinyCore", Arch: "megaavr", Desc: "ATtiny 0/1/2-series"},
}

type Config struct {
	Sketchbook  string
	ArduinoData string
	ConfigFile  string
}

func loadConfig() Config {
	home, _ := os.UserHomeDir()
	cfg := Config{ConfigFile: filepath.Join(home, configName)}
	if f, err := os.Open(cfg.ConfigFile); err == nil {
		defer f.Close()
		sc := bufio.NewScanner(f)
		for sc.Scan() {
			line := strings.TrimSpace(sc.Text())
			if strings.HasPrefix(line, "#") || !strings.Contains(line, "=") {
				continue
			}
			parts := strings.SplitN(line, "=", 2)
			value := strings.TrimSpace(parts[1])
			value = strings.Trim(value, "\"")
			switch strings.TrimSpace(parts[0]) {
			case "SKETCHBOOK":
				cfg.Sketchbook = value
			case "ARDUINO_DATA":
				cfg.ArduinoData = value
			}
		}
	}

	if cfg.Sketchbook == "" {
		cfg.Sketchbook = detectSketchbook()
	}
	if cfg.ArduinoData == "" {
		cfg.ArduinoData = detectArduinoData()
	}
	return cfg
}

func detectSketchbook() string {
	home, _ := os.UserHomeDir()
	var cliYAML, prefs string
	switch runtime.GOOS {
	case "linux":
		cliYAML = filepath.Join(home, ".arduino15", "arduino-cli.yaml")
		prefs = filepath.Join(home, ".arduino15", "preferences.txt")
	case "darwin":
		cliYAML = filepath.Join(home, "Library", "Arduino15", "arduino-cli.yaml")
		prefs = filepath.Join(home, "Library", "Arduino15", "preferences.txt")
	case "windows":
		appData := os.Getenv("APPDATA")
		localAppData := os.Getenv("LOCALAPPDATA")
		cliYAML = filepath.Join(localAppData, "Arduino15", "arduino-cli.yaml")
		prefs = filepath.Join(appData, "Arduino", "preferences.txt")
	}

	if v := parseKeyValueFile(cliYAML, "user"); v != "" {
		return v
	}
	if v := parseKeyValueFile(prefs, "sketchbook.path"); v != "" {
		return v
	}

	switch runtime.GOOS {
	case "darwin":
		return filepath.Join(home, "Documents", "Arduino")
	case "windows":
		return filepath.Join(os.Getenv("USERPROFILE"), "Documents", "Arduino")
	default:
		return filepath.Join(home, "Arduino")
	}
}

func detectArduinoData() string {
	home, _ := os.UserHomeDir()
	switch runtime.GOOS {
	case "linux":
		return filepath.Join(home, ".arduino15")
	case "darwin":
		return filepath.Join(home, "Library", "Arduino15")
	case "windows":
		if v := os.Getenv("LOCALAPPDATA"); v != "" {
			p := filepath.Join(v, "Arduino15")
			if _, err := os.Stat(p); err == nil {
				return p
			}
		}
		return filepath.Join(os.Getenv("APPDATA"), "Arduino")
	default:
		return filepath.Join(home, ".arduino15")
	}
}

func parseKeyValueFile(path, key string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if !strings.HasPrefix(line, key+":") && !strings.HasPrefix(line, key+"=") {
			continue
		}
		v := line[strings.IndexAny(line, ":=")+1:]
		v = strings.TrimSpace(strings.Trim(v, "\"'"))
		return v
	}
	return ""
}

func (c Config) LibDir() string      { return filepath.Join(c.Sketchbook, "libraries") }
func (c Config) HardwareDir() string { return filepath.Join(c.Sketchbook, "hardware") }
func (c Config) IndexFile() string   { return filepath.Join(c.ArduinoData, "library_index.json") }

func saveConfig(c Config) error {
	var b strings.Builder
	b.WriteString(fmt.Sprintf("SKETCHBOOK=%q\n", c.Sketchbook))
	b.WriteString(fmt.Sprintf("ARDUINO_DATA=%q\n", c.ArduinoData))
	return os.WriteFile(c.ConfigFile, []byte(b.String()), 0o600)
}

// Manager contains the non-GUI implementation of the original script.
type Manager struct {
	Config Config
	Client *http.Client
	Log    func(string)

	opMu  sync.RWMutex
	opCtx context.Context
}

func (m *Manager) logf(format string, args ...any) {
	if m.Log != nil {
		msg := fmt.Sprintf(format, args...)
		if strings.HasPrefix(msg, "ERROR:") && m.isCanceled() {
			msg = "CANCELLED: operation stopped by user"
		}
		m.Log(msg)
	}
}

func (m *Manager) setOperationContext(ctx context.Context) {
	m.opMu.Lock()
	m.opCtx = ctx
	m.opMu.Unlock()
}

func (m *Manager) clearOperationContext() {
	m.opMu.Lock()
	m.opCtx = nil
	m.opMu.Unlock()
}

func (m *Manager) operationContext() context.Context {
	m.opMu.RLock()
	ctx := m.opCtx
	m.opMu.RUnlock()
	if ctx == nil {
		return context.Background()
	}
	return ctx
}

func (m *Manager) isCanceled() bool {
	return m.operationContext().Err() == context.Canceled
}

func (m *Manager) ghGet(path string, out any) error {
	endpoint := "https://api.github.com/" + strings.TrimPrefix(path, "/")
	req, err := http.NewRequest(http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "Arduino-Go-Manager/1.0")
	req = req.WithContext(m.operationContext())
	resp, err := m.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 8<<10))
		return fmt.Errorf("GitHub API %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

func wordRank(name, query string) int {
	name = strings.ToLower(name)
	query = strings.ToLower(query)
	if query == "" || !strings.Contains(name, query) {
		return 2
	}
	for i := 0; ; {
		idx := strings.Index(name[i:], query)
		if idx < 0 {
			break
		}
		idx += i
		if idx == 0 || !isAlphaNum(name[idx-1]) {
			return 0
		}
		if idx+len(query) >= len(name) {
			return 1
		}
		i = idx + 1
	}
	return 1
}

func isAlphaNum(b byte) bool {
	return b >= 'a' && b <= 'z' || b >= '0' && b <= '9'
}

func (m *Manager) searchGitHub(query string, board bool, creator string, minStars int, sortBy, order string, limit int) ([]SearchItem, error) {
	q := url.QueryEscape(query)
	base := "arduino+"
	if board {
		base += q + "+core"
	} else {
		base += "library+" + q
	}
	if creator != "" {
		base += "+user:" + url.QueryEscape(creator)
	}
	if minStars > 0 {
		base += "+stars:>=" + strconv.Itoa(minStars)
	}
	fetch := func(extra string) ([]Repo, error) {
		var r struct {
			Items []Repo `json:"items"`
		}
		path := "search/repositories?q=" + base + extra + "&sort=" + url.QueryEscape(sortBy) + "&order=" + url.QueryEscape(order) + "&per_page=100"
		if err := m.ghGet(path, &r); err != nil {
			return nil, err
		}
		return r.Items, nil
	}

	var repos []Repo
	if board {
		name, err1 := fetch("+in:name")
		any, err2 := fetch("+in:description,readme")
		if err1 != nil {
			return nil, err1
		}
		if err2 != nil {
			return nil, err2
		}
		repos = append(name, any...)
	} else {
		name, err1 := fetch("+in:name")
		any, err2 := fetch("+in:description,readme")
		if err1 != nil {
			return nil, err1
		}
		if err2 != nil {
			return nil, err2
		}
		repos = append(name, any...)
	}

	seen := make(map[string]bool)
	result := make([]SearchItem, 0, len(repos))
	for i := range repos {
		if repos[i].FullName == "" || seen[repos[i].FullName] {
			continue
		}
		seen[repos[i].FullName] = true
		r := repos[i]
		result = append(result, SearchItem{Repo: &r, Kind: map[bool]string{true: "Board", false: "Library"}[board]})
	}
	sort.SliceStable(result, func(i, j int) bool {
		ri, rj := wordRank(result[i].Repo.Name, query), wordRank(result[j].Repo.Name, query)
		if ri != rj {
			return ri < rj
		}
		return result[i].Repo.Stars > result[j].Repo.Stars
	})
	if limit > 0 && len(result) > limit {
		result = result[:limit]
	}
	return result, nil
}

func (m *Manager) repo(repoName string) (*Repo, error) {
	var r Repo
	if err := m.ghGet("repos/"+strings.TrimPrefix(repoName, "/"), &r); err != nil {
		return nil, err
	}
	return &r, nil
}

func (m *Manager) tags(fullName string) ([]Tag, error) {
	var tags []Tag
	if err := m.ghGet("repos/"+fullName+"/tags?per_page=100", &tags); err != nil {
		return nil, err
	}
	return tags, nil
}

func (m *Manager) downloadFile(rawURL, target string) error {
	req, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return err
	}
	req = req.WithContext(m.operationContext())
	resp, err := m.Client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("download failed: %s", resp.Status)
	}
	f, err := os.Create(target)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, resp.Body)
	return err
}

func (m *Manager) unzipInto(zipPath, dest string) error {
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer r.Close()
	for _, f := range r.File {
		if err := m.operationContext().Err(); err != nil {
			return err
		}
		rel := filepath.Clean(f.Name)
		if rel == "." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) || filepath.IsAbs(rel) {
			continue
		}
		out := filepath.Join(dest, rel)
		if f.FileInfo().IsDir() {
			if err := os.MkdirAll(out, 0o755); err != nil {
				return err
			}
			continue
		}
		if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
			return err
		}
		in, err := f.Open()
		if err != nil {
			return err
		}
		outFile, err := os.OpenFile(out, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o644)
		if err != nil {
			in.Close()
			return err
		}
		_, cpErr := io.Copy(outFile, in)
		in.Close()
		outFile.Close()
		if cpErr != nil {
			return cpErr
		}
	}
	return nil
}

func (m *Manager) installLibraryZIP(rawURL, libName string) error {
	if rawURL == "" || libName == "" {
		return errors.New("missing library URL or name")
	}
	if err := os.MkdirAll(m.Config.LibDir(), 0o755); err != nil {
		return err
	}
	tmp, err := os.MkdirTemp("", "arduino-manager-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)
	zipPath := filepath.Join(tmp, "library.zip")
	m.logf("Downloading %s", rawURL)
	if err := m.downloadFile(rawURL, zipPath); err != nil {
		return err
	}
	extracted := filepath.Join(tmp, "extracted")
	if err := os.MkdirAll(extracted, 0o755); err != nil {
		return err
	}
	if err := m.unzipInto(zipPath, extracted); err != nil {
		return err
	}
	root, err := singleTopDir(extracted)
	if err != nil {
		return err
	}
	if err := m.operationContext().Err(); err != nil {
		return err
	}
	target := filepath.Join(m.Config.LibDir(), libName)
	if err := os.RemoveAll(target); err != nil {
		return err
	}
	if err := os.Rename(root, target); err != nil {
		return err
	}
	m.logf("Installed %s -> %s", libName, target)
	return nil
}

func singleTopDir(dir string) (string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return "", err
	}
	var dirs []string
	for _, e := range entries {
		if e.IsDir() {
			dirs = append(dirs, filepath.Join(dir, e.Name()))
		}
	}
	if len(dirs) == 1 {
		return dirs[0], nil
	}
	// Some archives contain files beside the directory; create a stable wrapper.
	wrapper := filepath.Join(dir, "_root")
	if err := os.MkdirAll(wrapper, 0o755); err != nil {
		return "", err
	}
	for _, e := range entries {
		src := filepath.Join(dir, e.Name())
		dst := filepath.Join(wrapper, e.Name())
		if err := os.Rename(src, dst); err != nil {
			return "", err
		}
	}
	return wrapper, nil
}

func (m *Manager) installGit(repoURL, target string, tag string, recursive bool) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	if _, err := os.Stat(target); err == nil {
		if tag != "" {
			m.logf("Updating %s to %s", target, tag)
			if err := m.runStreaming(target, "git", "fetch", "--depth", "1", "origin", "tag", tag); err != nil {
				return err
			}
			if err := m.runStreaming(target, "git", "checkout", tag); err != nil {
				return err
			}
			return nil
		}
		return m.runStreaming(target, "git", "pull")
	}
	args := []string{"clone"}
	if recursive {
		args = append(args, "--recursive")
	}
	if tag != "" {
		args = append(args, "--depth", "1", "--branch", tag)
	}
	args = append(args, repoURL, target)
	m.logf("Cloning %s", repoURL)
	return m.runStreaming("", "git", args...)
}

func (m *Manager) installLibraryGit(repo *Repo) error {
	libName := repo.Name
	target := filepath.Join(m.Config.LibDir(), libName)
	return m.installGit(repo.CloneURL, target, "", false)
}

func (m *Manager) installLibraryTag(repo *Repo, tag string) error {
	return m.installGit(repo.CloneURL, filepath.Join(m.Config.LibDir(), repo.Name), tag, false)
}

func guessBoardNames(fullName string) (string, string) {
	known := map[string][2]string{
		"esp8266/Arduino":                    {"esp8266", "esp8266"},
		"espressif/arduino-esp32":            {"espressif", "esp32"},
		"espressif/esp32":                    {"espressif", "esp32"},
		"adafruit/Adafruit_nRF52_Arduino":    {"adafruit", "nrf52"},
		"arduino/ArduinoCore-avr":            {"arduino", "avr"},
		"arduino/ArduinoCore-megaavr":        {"arduino", "megaavr"},
		"arduino/ArduinoCore-samd":           {"arduino", "samd"},
		"arduino/ArduinoCore-mbed":           {"arduino", "mbed"},
		"arduino/ArduinoCore-nRF528x-mbedos": {"arduino", "nrf52840"},
		"arduino/ArduinoCore-renesas":        {"arduino", "renesas"},
		"stm32duino/Arduino_Core_STM32":      {"stm32duino", "stm32"},
		"SpenceKonde/ATTinyCore":             {"ATTinyCore", "avr"},
		"SpenceKonde/megaTinyCore":           {"megaTinyCore", "megaavr"},
	}
	if x, ok := known[fullName]; ok {
		return x[0], x[1]
	}
	parts := strings.SplitN(fullName, "/", 2)
	owner, repo := parts[0], parts[len(parts)-1]
	arch := strings.ToLower(repo)
	for _, prefix := range []string{"arduino-", "arduino_", "arduinocore-", "arduinocore_"} {
		arch = strings.TrimPrefix(arch, prefix)
	}
	arch = strings.TrimSuffix(arch, "_core")
	arch = strings.TrimSuffix(arch, "-core")
	if arch == "" {
		arch = "core"
	}
	return strings.ToLower(owner), arch
}

func (m *Manager) installBoard(repo *Repo, vendor, arch, tag string) error {
	base := filepath.Join(m.Config.HardwareDir(), vendor)
	target := filepath.Join(base, arch)
	if _, err := os.Stat(target); err == nil {
		if tag != "" {
			if err := m.runStreaming(target, "git", "fetch", "--depth", "1", "origin", "tag", tag); err != nil {
				return err
			}
			if err := m.runStreaming(target, "git", "checkout", tag); err != nil {
				return err
			}
			return nil
		}
		if err := m.runStreaming(target, "git", "pull"); err != nil {
			return err
		}
		return m.runStreaming(target, "git", "submodule", "update", "--init", "--recursive")
	}
	if err := os.MkdirAll(base, 0o755); err != nil {
		return err
	}
	repoName := filepath.Base(strings.TrimSuffix(repo.HTMLURL, "/"))
	cloneDir := filepath.Join(base, repoName)
	args := []string{"clone", "--recursive"}
	if tag != "" {
		args = append(args, "--depth", "1", "--branch", tag)
	}
	args = append(args, repo.CloneURL, cloneDir)
	if err := m.runStreaming("", "git", args...); err != nil {
		_ = os.RemoveAll(cloneDir)
		return err
	}
	// Preserve the original script's special nested-core handling.
	nested := filepath.Join(cloneDir, arch, "boards.txt")
	if _, err := os.Stat(nested); err == nil {
		coreDir := filepath.Join(cloneDir, arch)
		if err := os.MkdirAll(target, 0o755); err != nil {
			return err
		}
		entries, err := os.ReadDir(coreDir)
		if err != nil {
			return err
		}
		for _, e := range entries {
			if err := os.Rename(filepath.Join(coreDir, e.Name()), filepath.Join(target, e.Name())); err != nil {
				return err
			}
		}
		_ = os.RemoveAll(cloneDir)
		return nil
	}
	if repoName != arch {
		if err := os.Rename(cloneDir, target); err != nil {
			return err
		}
	}
	return nil
}

func (m *Manager) setupBoard(vendor, arch string) error {
	target := filepath.Join(m.Config.HardwareDir(), vendor, arch)
	if st, err := os.Stat(target); err != nil || !st.IsDir() {
		return fmt.Errorf("board not found: %s", target)
	}
	if _, err := os.Stat(filepath.Join(target, "tools", "get.py")); err == nil {
		python := "python3"
		if runtime.GOOS == "windows" {
			python = "py"
		}
		return m.runStreaming(target, python, filepath.Join(target, "tools", "get.py"))
	}
	if _, err := os.Stat(filepath.Join(target, "tools", "install.sh")); err == nil {
		return m.runShellScript(target, filepath.Join(target, "tools", "install.sh"))
	}
	if _, err := os.Stat(filepath.Join(target, "post_install.sh")); err == nil {
		return m.runShellScript(target, filepath.Join(target, "post_install.sh"))
	}
	return fmt.Errorf("no standard setup script found in %s", target)
}

func (m *Manager) runShellScript(dir, script string) error {
	if runtime.GOOS == "windows" {
		return fmt.Errorf("setup script is a shell script; run it from a Unix-like shell on Windows")
	}
	return m.runStreaming(dir, "bash", script)
}

func (m *Manager) runStreaming(dir, name string, args ...string) error {
	cmd := exec.CommandContext(m.operationContext(), name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	var buf bytes.Buffer
	cmd.Stdout = io.MultiWriter(&buf, logWriter{m})
	cmd.Stderr = io.MultiWriter(&buf, logWriter{m})
	err := cmd.Run()
	if err != nil {
		if out := strings.TrimSpace(buf.String()); out != "" {
			return fmt.Errorf("%s: %w\n%s", name, err, out)
		}
		return fmt.Errorf("%s: %w", name, err)
	}
	return nil
}

type logWriter struct{ m *Manager }

func (w logWriter) Write(p []byte) (int, error) {
	for _, line := range strings.Split(strings.ReplaceAll(string(p), "\r\n", "\n"), "\n") {
		line = strings.TrimRight(line, "\r")
		if line != "" {
			w.m.logf("%s", line)
		}
	}
	return len(p), nil
}

func (m *Manager) updateIndex() error {
	tmp, err := os.CreateTemp("", "arduino-index-*.json")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	tmp.Close()
	m.logf("Downloading official Arduino library index...")
	if err := m.downloadFile("https://downloads.arduino.cc/libraries/library_index.json", tmpPath); err != nil {
		return fmt.Errorf("Arduino index download: %w", err)
	}
	var idx LibraryIndex
	f, err := os.Open(tmpPath)
	if err != nil {
		return err
	}
	if err := json.NewDecoder(f).Decode(&idx); err != nil {
		f.Close()
		return fmt.Errorf("invalid library index: %w", err)
	}
	f.Close()
	if err := os.MkdirAll(filepath.Dir(m.Config.IndexFile()), 0o755); err != nil {
		return err
	}
	data, _ := os.ReadFile(tmpPath)
	if err := os.WriteFile(m.Config.IndexFile(), data, 0o644); err != nil {
		return err
	}
	m.logf("Index saved: %d libraries", len(idx.Libraries))
	return nil
}

func (m *Manager) loadIndex() (*LibraryIndex, error) {
	f, err := os.Open(m.Config.IndexFile())
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var idx LibraryIndex
	if err := json.NewDecoder(f).Decode(&idx); err != nil {
		return nil, err
	}
	groups := make(map[string]*IndexLibrary)
	for _, item := range idx.Libraries {
		g := groups[item.Name]
		if g == nil {
			copyItem := item
			copyItem.Versions = nil
			groups[item.Name] = ©Item
			g = ©Item
		}
		g.Versions = append(g.Versions, IndexVersion{Version: item.Version, URL: item.URL})
	}
	idx.Libraries = idx.Libraries[:0]
	for _, v := range groups {
		sort.Slice(v.Versions, func(i, j int) bool { return v.Versions[i].Version > v.Versions[j].Version })
		idx.Libraries = append(idx.Libraries, *v)
	}
	sort.Slice(idx.Libraries, func(i, j int) bool {
		return strings.ToLower(idx.Libraries[i].Name) < strings.ToLower(idx.Libraries[j].Name)
	})
	return &idx, nil
}

func (m *Manager) searchIndex(query string) ([]SearchItem, error) {
	idx, err := m.loadIndex()
	if err != nil {
		return nil, err
	}
	q := strings.ToLower(query)
	var result []SearchItem
	for i := range idx.Libraries {
		lib := idx.Libraries[i]
		if strings.Contains(strings.ToLower(lib.Name), q) {
			copyItem := lib
			result = append(result, SearchItem{Library: ©Item, Kind: "Local library"})
		}
	}
	return result, nil
}

func (m *Manager) listLibraries(scanAll bool, customPath string) ([]string, error) {
	paths := []string{}
	if customPath != "" {
		paths = append(paths, customPath)
	} else {
		paths = append(paths, m.Config.LibDir(), filepath.Join(m.Config.ArduinoData, "libraries"))
		if scanAll {
			home, _ := os.UserHomeDir()
			_ = filepath.WalkDir(home, func(path string, d os.DirEntry, err error) error {
				if err != nil || !d.IsDir() {
					return nil
				}
				if d.Name() == "node_modules" || d.Name() == ".cache" || d.Name() == ".config" {
					return filepath.SkipDir
				}
				if d.Name() == "libraries" {
					paths = append(paths, path)
				}
				return nil
			})
		}
	}
	seen := make(map[string]bool)
	var libs []string
	for _, root := range paths {
		entries, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if !e.IsDir() || strings.HasPrefix(e.Name(), ".") || seen[filepath.Join(root, e.Name())] {
				continue
			}
			seen[filepath.Join(root, e.Name())] = true
			libs = append(libs, fmt.Sprintf("%s\t%s", e.Name(), libraryVersion(filepath.Join(root, e.Name()))))
		}
	}
	if len(libs) == 0 {
		return nil, errors.New("no library directories found")
	}
	sort.Strings(libs)
	return libs, nil
}

func libraryVersion(dir string) string {
	f, err := os.Open(filepath.Join(dir, "library.properties"))
	if err != nil {
		return "IDE 1 only"
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if strings.HasPrefix(line, "version=") {
			v := strings.TrimSpace(strings.TrimPrefix(line, "version="))
			if v != "" {
				return "v" + v
			}
		}
	}
	return "vunknown"
}

func (m *Manager) listBoards() []string {
	root := m.Config.HardwareDir()
	var result []string
	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if d.IsDir() || d.Name() != "boards.txt" {
			return nil
		}
		rel, _ := filepath.Rel(root, filepath.Dir(path))
		result = append(result, rel)
		return nil
	})
	sort.Strings(result)
	return result
}

func removeLibrary(cfg Config, name string) error {
	return os.RemoveAll(filepath.Join(cfg.LibDir(), filepath.Base(name)))
}

func removeBoard(cfg Config, vendor, arch string) error {
	return os.RemoveAll(filepath.Join(cfg.HardwareDir(), filepath.Base(vendor), filepath.Base(arch)))
}

// -------- GUI --------

// searchEntry adds an Escape handler on top of Fyne's regular single-line Entry.
// This makes cancelling an active operation work even while the search box has focus.
type searchEntry struct {
	widget.Entry
	onEscape func()
}

func newSearchEntry(onEscape func()) *searchEntry {
	e := &searchEntry{onEscape: onEscape}
	e.ExtendBaseWidget(e)
	return e
}

func (e *searchEntry) TypedKey(ev *fyne.KeyEvent) {
	if ev != nil && ev.Name == fyne.KeyEscape && e.onEscape != nil {
		e.onEscape()
		return
	}
	e.Entry.TypedKey(ev)
}

// minSizeObject is a lightweight wrapper widget that exposes a practical
// minimum size while still rendering and resizing the wrapped CanvasObject.
// A plain struct embedding fyne.CanvasObject is not enough: Fyne renders the
// object tree through the widget renderer, so this wrapper must explicitly
// expose the child from its renderer.
type minSizeObject struct {
	widget.BaseWidget
	child fyne.CanvasObject
	min   fyne.Size
}

func newMinSizeObject(obj fyne.CanvasObject, min fyne.Size) *minSizeObject {
	o := &minSizeObject{child: obj, min: min}
	o.ExtendBaseWidget(o)
	return o
}

func (o *minSizeObject) MinSize() fyne.Size {
	childMin := o.child.MinSize()
	return fyne.NewSize(
		maxFloat32(childMin.Width, o.min.Width),
		maxFloat32(childMin.Height, o.min.Height),
	)
}

func maxFloat32(a, b float32) float32 {
	if a > b {
		return a
	}
	return b
}

func (o *minSizeObject) CreateRenderer() fyne.WidgetRenderer {
	return &minSizeObjectRenderer{object: o}
}

type minSizeObjectRenderer struct {
	object *minSizeObject
}

func (r *minSizeObjectRenderer) Layout(size fyne.Size) {
	r.object.child.Move(fyne.NewPos(0, 0))
	r.object.child.Resize(size)
}

func (r *minSizeObjectRenderer) MinSize() fyne.Size {
	return r.object.MinSize()
}

func (r *minSizeObjectRenderer) Objects() []fyne.CanvasObject {
	return []fyne.CanvasObject{r.object.child}
}

func (r *minSizeObjectRenderer) Refresh() {
	r.object.child.Refresh()
}

func (r *minSizeObjectRenderer) Destroy() {}

// resultRow keeps each result row inside the list width and truncates long text.
// Fyne's List reuses the same row widget, so this avoids a description growing
// beyond the result pane when a repository has a very long description.
type resultRow struct {
	widget.BaseWidget
	title *widget.Label
	meta  *widget.Label
	desc  *widget.Label
}

func newResultRow() *resultRow {
	r := &resultRow{
		title: widget.NewLabel(""),
		meta:  widget.NewLabel(""),
		desc:  widget.NewLabel(""),
	}
	r.title.TextStyle = fyne.TextStyle{Bold: true}
	r.title.Truncation = fyne.TextTruncateEllipsis
	r.meta.Truncation = fyne.TextTruncateEllipsis
	r.desc.Truncation = fyne.TextTruncateEllipsis
	r.ExtendBaseWidget(r)
	return r
}

func (r *resultRow) CreateRenderer() fyne.WidgetRenderer {
	header := container.NewBorder(nil, nil, nil, r.meta, r.title)
	return widget.NewSimpleRenderer(container.NewVBox(header, r.desc))
}

type App struct {
	fyneApp fyne.App
	win     fyne.Window
	mgr     *Manager

	mode          string
	modeSelect    *widget.Select
	modeSelectMin fyne.CanvasObject
	query         *searchEntry
	queryMin      fyne.CanvasObject
	creator       *widget.Entry
	creatorMin    fyne.CanvasObject
	minStars      *widget.Entry
	minStarsMin   fyne.CanvasObject
	limit         *widget.Entry
	limitMin      fyne.CanvasObject
	sortSelect    *widget.Select
	sortSelectMin fyne.CanvasObject
	order         *widget.Select
	orderMin      fyne.CanvasObject

	results       *widget.List
	detail        *widget.RichText
	detailActions *fyne.Container
	logBox        *widget.Entry
	status        *widget.Label
	cancel        *widget.Button
	shortcutHint  *widget.Label
	items         []SearchItem

	busyMu   sync.Mutex
	busy     bool
	cancelFn context.CancelFunc
}

func newApp() *App {
	a := app.NewWithID(appID)
	a.Settings().SetTheme(theme.DarkTheme())
	win := a.NewWindow(appTitle)
	cfg := loadConfig()
	manager := &Manager{Config: cfg, Client: &http.Client{Timeout: 60 * time.Second}}
	app := &App{fyneApp: a, win: win, mgr: manager, mode: "Libraries"}
	manager.Log = func(s string) {
		fyne.Do(func() {
			app.appendLog(s)
		})
	}
	app.build()
	win.Resize(fyne.NewSize(1320, 840))
	win.SetFixedSize(false)
	return app
}

func (a *App) cancelOperation() {
	a.busyMu.Lock()
	cancel := a.cancelFn
	busy := a.busy
	a.busyMu.Unlock()
	if !busy || cancel == nil {
		return
	}
	cancel()
	a.appendLog("Cancellation requested…")
	fyne.Do(func() {
		if a.status != nil {
			a.status.SetText("Cancelling…")
		}
	})
}

func (a *App) installShortcuts() {
	c := a.win.Canvas()
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.KeyF, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		c.Focus(a.query)
	})
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.KeyL, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		c.Focus(a.query)
	})
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.KeyK, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		a.query.SetText("")
	})
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.Key1, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		a.setMode("Libraries")
	})
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.Key2, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		a.setMode("Boards")
	})
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.Key3, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		a.setMode("Local index")
	})
	c.AddShortcut(&desktop.CustomShortcut{KeyName: fyne.KeyR, Modifier: fyne.KeyModifierControl}, func(fyne.Shortcut) {
		if strings.TrimSpace(a.query.Text) != "" {
			a.search()
		}
	})
	// Escape has no modifier, so handle it at canvas level. Fyne delivers
	// these events globally; when an operation is running it becomes Cancel.
	previous := c.OnTypedKey()
	c.SetOnTypedKey(func(ev *fyne.KeyEvent) {
		if ev != nil && ev.Name == fyne.KeyEscape {
			a.cancelOperation()
			return
		}
		if previous != nil {
			previous(ev)
		}
	})
}

func (a *App) build() {
	a.query = newSearchEntry(a.cancelOperation)
	a.query.SetPlaceHolder("Search GitHub for Arduino libraries...")
	a.queryMin = newMinSizeObject(a.query, fyne.NewSize(420, 36))
	a.creator = widget.NewEntry()
	a.creator.SetPlaceHolder("GitHub user")
	a.creatorMin = newMinSizeObject(a.creator, fyne.NewSize(170, 36))
	a.minStars = widget.NewEntry()
	a.minStars.SetText("0")
	a.minStarsMin = newMinSizeObject(a.minStars, fyne.NewSize(100, 36))
	a.limit = widget.NewEntry()
	a.limit.SetText("15")
	a.limitMin = newMinSizeObject(a.limit, fyne.NewSize(90, 36))
	a.sortSelect = widget.NewSelect([]string{"stars", "forks", "updated"}, nil)
	a.sortSelect.SetSelected("stars")
	a.sortSelectMin = newMinSizeObject(a.sortSelect, fyne.NewSize(130, 36))
	a.order = widget.NewSelect([]string{"desc", "asc"}, nil)
	a.order.SetSelected("desc")
	a.orderMin = newMinSizeObject(a.order, fyne.NewSize(100, 36))

	a.modeSelect = widget.NewSelect([]string{"Libraries", "Boards", "Local index"}, func(v string) {
		a.setMode(v)
	})
	a.modeSelect.SetSelected("Libraries")
	a.modeSelectMin = newMinSizeObject(a.modeSelect, fyne.NewSize(160, 36))

	a.status = widget.NewLabel("Ready")
	a.status.TextStyle = fyne.TextStyle{Bold: true}
	a.cancel = widget.NewButtonWithIcon("Cancel", theme.CancelIcon(), func() { a.cancelOperation() })
	a.cancel.Hide()

	searchBtn := widget.NewButtonWithIcon("Search", theme.SearchIcon(), func() { a.search() })
	clearBtn := widget.NewButton("Clear", func() {
		a.query.SetText("")
		a.items = nil
		a.results.Refresh()
		a.clearDetails()
		a.status.SetText("Ready")
	})

	// ----- Left navigation ---------------------------------------------------
	brand := widget.NewLabel("ARDUINO MANAGER")
	brand.TextStyle = fyne.TextStyle{Bold: true}
	navHint := widget.NewLabel("Library & board management")
	navHint.TextStyle = fyne.TextStyle{Italic: true}

	navLibraries := widget.NewButtonWithIcon("Libraries", theme.StorageIcon(), func() { a.setMode("Libraries") })
	navBoards := widget.NewButtonWithIcon("Board cores", theme.ComputerIcon(), func() { a.setMode("Boards") })
	navIndex := widget.NewButton("Local index", func() { a.setMode("Local index") })
	navPopular := widget.NewButtonWithIcon("Popular cores", theme.StorageIcon(), func() { a.showPopularCores() })

	installedLibs := widget.NewButton("Installed libraries", func() { a.listInstalledLibraries() })
	installedBoards := widget.NewButton("Installed boards", func() { a.listInstalledBoards() })
	configBtn := widget.NewButtonWithIcon("Configuration", theme.SettingsIcon(), func() { a.showConfig() })

	updateBtn := widget.NewButtonWithIcon("Update index", theme.DownloadIcon(), func() { a.updateIndex() })
	importBtn := widget.NewButton("Import index", func() { a.importIndexDialog() })
	repoBtn := widget.NewButton("Install GitHub repo", func() { a.installRepoDialog() })

	nav := container.NewVBox(
		brand,
		navHint,
		widget.NewSeparator(),
		navLibraries,
		navBoards,
		navIndex,
		widget.NewSeparator(),
		navPopular,
		installedLibs,
		installedBoards,
		widget.NewSeparator(),
		updateBtn,
		importBtn,
		repoBtn,
		configBtn,
	)
	sidebar := container.NewBorder(nil, nil, nil, nil, container.NewPadded(container.NewVScroll(nav)))
	sidebarObj := newMinSizeObject(sidebar, fyne.NewSize(250, 0))

	// ----- Header ------------------------------------------------------------
	title := widget.NewLabel("Arduino Manager")
	title.TextStyle = fyne.TextStyle{Bold: true, Monospace: false}
	title.Alignment = fyne.TextAlignLeading
	subtitle := widget.NewLabel("GitHub-backed Arduino library & board manager")
	subtitle.TextStyle = fyne.TextStyle{Italic: true}
	headerLeft := container.NewVBox(title, subtitle)
	headerRight := container.NewHBox(widget.NewLabel("Status:"), a.status, a.cancel)
	header := container.NewBorder(nil, nil, headerLeft, headerRight, nil)

	// ----- Search area -------------------------------------------------------
	modeLine := container.NewGridWithColumns(4,
		container.NewBorder(nil, nil, widget.NewLabel("Mode"), nil, a.modeSelectMin),
		container.NewBorder(nil, nil, widget.NewLabel("Limit"), nil, a.limitMin),
		container.NewBorder(nil, nil, widget.NewLabel("Creator"), nil, a.creatorMin),
		container.NewBorder(nil, nil, widget.NewLabel("Min stars"), nil, a.minStarsMin),
	)
	sortLine := container.NewGridWithColumns(2,
		container.NewBorder(nil, nil, widget.NewLabel("Sort"), nil, a.sortSelectMin),
		container.NewBorder(nil, nil, widget.NewLabel("Order"), nil, a.orderMin),
	)
	queryLine := container.NewBorder(nil, nil, widget.NewLabel("Search"), container.NewHBox(clearBtn, searchBtn), a.queryMin)
	searchCard := widget.NewCard("Search", "Use GitHub search or the local Arduino library index.", container.NewVBox(queryLine, modeLine, sortLine))
	searchCardObj := newMinSizeObject(searchCard, fyne.NewSize(0, 176))

	// ----- Results -----------------------------------------------------------
	a.results = widget.NewList(
		func() int { return len(a.items) },
		func() fyne.CanvasObject { return newResultRow() },
		func(id widget.ListItemID, obj fyne.CanvasObject) {
			row := obj.(*resultRow)
			if id < 0 || id >= len(a.items) {
				row.title.SetText("")
				row.meta.SetText("")
				row.desc.SetText("")
				return
			}
			item := a.items[id]
			if item.Repo != nil {
				row.title.SetText(item.Repo.FullName)
				row.meta.SetText(fmt.Sprintf("%s  •  ⭐ %d", item.Kind, item.Repo.Stars))
				row.desc.SetText(strings.TrimSpace(item.Repo.Description))
			} else if item.Library != nil {
				row.title.SetText(item.Library.Name)
				row.meta.SetText(fmt.Sprintf("Local index  •  %d version(s)", len(item.Library.Versions)))
				row.desc.SetText(strings.TrimSpace(item.Library.Sentence))
			}
		},
	)
	a.results.OnSelected = func(id widget.ListItemID) { a.showItem(id) }

	a.detail = widget.NewRichTextFromMarkdown("### Arduino Manager\n\nSelect an item on the left to see its details and available actions.")
	a.detail.Wrapping = fyne.TextWrapWord
	a.detailActions = container.NewHBox()
	a.clearDetails()

	resultTitle := widget.NewLabel("RESULTS")
	resultTitle.TextStyle = fyne.TextStyle{Bold: true}
	detailTitle := widget.NewLabel("DETAILS")
	detailTitle.TextStyle = fyne.TextStyle{Bold: true}

	resultPanel := container.NewBorder(resultTitle, nil, nil, nil, container.NewPadded(a.results))
	detailPanel := container.NewBorder(detailTitle, container.NewPadded(a.detailActions), nil, nil, container.NewPadded(container.NewVScroll(a.detail)))
	resultPanelObj := newMinSizeObject(resultPanel, fyne.NewSize(450, 0))
	detailPanelObj := newMinSizeObject(detailPanel, fyne.NewSize(500, 0))
	contentSplit := container.NewHSplit(resultPanelObj, detailPanelObj)
	contentSplit.SetOffset(0.42)

	// ----- Activity log -----------------------------------------------------
	a.logBox = widget.NewMultiLineEntry()
	a.logBox.Disable()
	a.logBox.SetMinRowsVisible(1)
	a.logBox.SetText("Ready.\n")
	logTitle := widget.NewLabel("ACTIVITY LOG  ↕ Drag divider to resize")
	logTitle.TextStyle = fyne.TextStyle{Bold: true}
	// Keep the activity log compact and, importantly, let the VSplit really
	// resize it. A MultiLineEntry has a non-trivial minimum height, so putting
	// it directly into the Split can make the divider appear stuck. Wrapping
	// the entry in a vertical scroll gives the bottom pane a small minimum size
	// while preserving scrolling when there are many log lines.
	logToggle := widget.NewButton("Hide", nil)
	logPanelBody := newMinSizeObject(container.NewVScroll(a.logBox), fyne.NewSize(0, 0))
	logHeader := container.NewBorder(nil, nil, logTitle, logToggle)
	logPanel := container.NewBorder(logHeader, nil, nil, nil, logPanelBody)
	mainSplit := container.NewVSplit(contentSplit, logPanel)
	mainSplit.SetOffset(0.82)
	logCollapsed := false
	logToggle.OnTapped = func() {
		logCollapsed = !logCollapsed
		if logCollapsed {
			logPanelBody.Hide()
			logToggle.SetText("Show")
			mainSplit.SetOffset(0.95)
		} else {
			logPanelBody.Show()
			logToggle.SetText("Hide")
			mainSplit.SetOffset(0.82)
		}
		mainSplit.Refresh()
	}

	a.shortcutHint = widget.NewLabel("Enter = Search  •  Ctrl+F = Focus  •  Ctrl+K = Clear  •  Ctrl+1/2/3 = Mode  •  Ctrl+R = Repeat  •  Esc = Cancel")
	a.shortcutHint.TextStyle = fyne.TextStyle{Italic: true}
	a.shortcutHint.Truncation = fyne.TextTruncateEllipsis
	// Do not put mainSplit inside VBox: VBox gives children their MinSize,
	// which leaves a VSplit with almost no free height and makes its divider
	// appear stuck. Border gives the split all remaining vertical space, so
	// the horizontal divider is genuinely draggable.
	center := container.NewBorder(searchCardObj, a.shortcutHint, nil, nil, mainSplit)
	workspace := container.NewBorder(header, nil, sidebarObj, nil, center)
	a.win.SetContent(container.NewPadded(workspace))
	a.query.OnSubmitted = func(_ string) { a.search() }
	a.installShortcuts()
}

func (a *App) setMode(mode string) {
	a.mode = mode
	if a.modeSelect != nil && a.modeSelect.Selected != mode {
		a.modeSelect.SetSelected(mode)
	}
	if mode == "Local index" {
		a.creator.Disable()
		a.minStars.Disable()
		a.sortSelect.Disable()
		a.order.Disable()
		a.query.SetPlaceHolder("Search the local Arduino library index...")
	} else {
		a.creator.Enable()
		a.minStars.Enable()
		a.sortSelect.Enable()
		a.order.Enable()
		if mode == "Boards" {
			a.query.SetPlaceHolder("Search GitHub for Arduino board cores...")
		} else {
			a.query.SetPlaceHolder("Search GitHub for Arduino libraries...")
		}
	}
	a.items = nil
	if a.results != nil {
		a.results.Refresh()
	}
	a.clearDetails()
	if a.status != nil {
		a.status.SetText(mode)
	}
}

func (a *App) clearDetails() {
	if a.detail != nil {
		a.detail.ParseMarkdown("### Arduino Manager\n\nSelect an item on the left to see its details and available actions.")
	}
	if a.detailActions != nil {
		a.detailActions.Objects = nil
		a.detailActions.Refresh()
	}
}

func (a *App) withBusy(fn func()) {
	a.busyMu.Lock()
	if a.busy {
		a.busyMu.Unlock()
		a.appendLog("An operation is already running.")
		return
	}
	ctx, cancel := context.WithCancel(context.Background())
	a.busy = true
	a.cancelFn = cancel
	a.busyMu.Unlock()
	a.mgr.setOperationContext(ctx)
	fyne.Do(func() {
		if a.status != nil {
			a.status.SetText("Working…")
		}
		if a.cancel != nil {
			a.cancel.Show()
		}
	})
	go func() {
		defer func() {
			a.mgr.clearOperationContext()
			cancel()
			a.busyMu.Lock()
			a.busy = false
			a.cancelFn = nil
			a.busyMu.Unlock()
			fyne.Do(func() {
				if a.cancel != nil {
					a.cancel.Hide()
				}
				if a.status != nil {
					a.status.SetText("Ready")
				}
			})
		}()
		fn()
	}()
}

func (a *App) search() {
	q := strings.TrimSpace(a.query.Text)
	if q == "" {
		a.appendLog("Enter a search query.")
		return
	}
	limit, _ := strconv.Atoi(strings.TrimSpace(a.limit.Text))
	if limit <= 0 {
		limit = 15
	}
	stars, _ := strconv.Atoi(strings.TrimSpace(a.minStars.Text))
	a.withBusy(func() {
		var items []SearchItem
		var err error
		switch a.mode {
		case "Local index":
			items, err = a.mgr.searchIndex(q)
		default:
			items, err = a.mgr.searchGitHub(q, a.mode == "Boards", strings.TrimSpace(a.creator.Text), stars, a.sortSelect.Selected, a.order.Selected, limit)
		}
		if err != nil {
			a.mgr.logf("ERROR: %v", err)
			return
		}
		fyne.Do(func() {
			a.items = items
			a.results.Refresh()
			a.detail.ParseMarkdown("### Results\nSelect an item to inspect it.")
			a.appendLog(fmt.Sprintf("Found %d result(s).", len(items)))
		})
	})
}

func (a *App) setDetailActions(objects ...fyne.CanvasObject) {
	a.detailActions.Objects = objects
	a.detailActions.Refresh()
}

func (a *App) showItem(id widget.ListItemID) {
	if id < 0 || id >= len(a.items) {
		a.clearDetails()
		return
	}
	item := a.items[id]
	if item.Repo != nil {
		r := item.Repo
		description := strings.TrimSpace(r.Description)
		if description == "" {
			description = "No description provided by GitHub."
		}
		markdown := fmt.Sprintf(
			"### %s\n\n**Type:** %s  \n**Stars:** ⭐ %d  \n**Default branch:** `%s`  \n**Repository:** `%s`\n\n%s",
			r.FullName, item.Kind, r.Stars, r.DefaultBranch, r.HTMLURL, description,
		)
		a.detail.ParseMarkdown(markdown)
		a.setDetailActions(
			widget.NewButtonWithIcon("Install / update latest", theme.DownloadIcon(), func() {
				a.installRepo(r, item.Kind, "")
			}),
			widget.NewButton("Versions / tags", func() {
				a.showTags(r, item.Kind)
			}),
		)
		return
	}
	if item.Library != nil {
		lib := item.Library
		versions := make([]string, 0, len(lib.Versions))
		for _, v := range lib.Versions {
			versions = append(versions, v.Version)
		}
		text := fmt.Sprintf("### %s\n\n**Source:** Local Arduino library index  \n**Versions:** %d\n\n%s", lib.Name, len(lib.Versions), strings.TrimSpace(lib.Sentence))
		a.detail.ParseMarkdown(text)
		if len(lib.Versions) == 0 {
			a.setDetailActions(widget.NewLabel("No downloadable versions found in the local index."))
			return
		}
		selectWidget := widget.NewSelect(versions, nil)
		selectWidget.SetSelected(versions[0])
		installBtn := widget.NewButtonWithIcon("Install selected version", theme.DownloadIcon(), func() {
			idx := 0
			for i, v := range lib.Versions {
				if v.Version == selectWidget.Selected {
					idx = i
					break
				}
			}
			v := lib.Versions[idx]
			a.withBusy(func() {
				err := a.mgr.installLibraryZIP(v.URL, lib.Name)
				if err != nil {
					a.mgr.logf("ERROR: %v", err)
				} else {
					a.mgr.logf("Installed %s %s", lib.Name, v.Version)
				}
			})
		})
		a.setDetailActions(selectWidget, installBtn)
	}
}

func (a *App) showTags(repo *Repo, kind string) {
	a.withBusy(func() {
		tags, err := a.mgr.tags(repo.FullName)
		if err != nil {
			a.mgr.logf("ERROR: %v", err)
			return
		}
		labels := make([]string, len(tags))
		for i, t := range tags {
			labels[i] = t.Name
		}
		fyne.Do(func() {
			selectWidget := widget.NewSelect(labels, nil)
			if len(labels) > 0 {
				selectWidget.SetSelected(labels[0])
			}
			install := widget.NewButton("Install selected", func() {
				selected := selectWidget.Selected
				if selected == "" {
					return
				}
				a.installRepo(repo, kind, selected)
			})
			latest := widget.NewButton("Install latest", func() { a.installRepo(repo, kind, "") })
			content := container.NewVBox(widget.NewLabel(fmt.Sprintf("%d tag(s)", len(tags))), selectWidget, container.NewHBox(install, latest))
			dialog.ShowCustom("Versions: "+repo.FullName, "Close", content, a.win)
		})
	})
}

func (a *App) installRepo(repo *Repo, kind, tag string) {
	if kind == "Board" {
		vendor, arch := guessBoardNames(repo.FullName)
		vendorEntry := widget.NewEntry()
		vendorEntry.SetText(vendor)
		archEntry := widget.NewEntry()
		archEntry.SetText(arch)
		install := func() {
			a.withBusy(func() {
				err := a.mgr.installBoard(repo, vendorEntry.Text, archEntry.Text, tag)
				if err != nil {
					a.mgr.logf("ERROR: %v", err)
				} else {
					a.mgr.logf("Board installed: hardware/%s/%s", vendorEntry.Text, archEntry.Text)
				}
			})
		}
		content := container.NewVBox(
			widget.NewLabel("Vendor folder"), vendorEntry,
			widget.NewLabel("Architecture folder"), archEntry,
			widget.NewLabel(fmt.Sprintf("Install path: %s", filepath.Join(a.mgr.Config.HardwareDir(), vendorEntry.Text, archEntry.Text))),
		)
		dialog.ShowCustomConfirm("Board destination", "Install", "Cancel", content, func(ok bool) {
			if ok {
				install()
			}
		}, a.win)
		return
	}
	a.withBusy(func() {
		var err error
		if tag == "" {
			err = a.mgr.installLibraryGit(repo)
		} else {
			err = a.mgr.installLibraryTag(repo, tag)
		}
		if err != nil {
			a.mgr.logf("ERROR: %v", err)
		} else {
			a.mgr.logf("Library installed: %s", repo.Name)
		}
	})
}

func (a *App) showPopularCores() {
	rows := make([]fyne.CanvasObject, 0, len(popularCores))
	for _, core := range popularCores {
		c := core
		rows = append(rows, container.NewBorder(nil, nil, widget.NewLabel(c.Label), widget.NewButton("Install", func() {
			a.installPopular(c)
		}), widget.NewLabel(c.Desc)))
	}
	dialog.ShowCustom("Popular board cores", "Close", container.NewVScroll(container.NewVBox(rows...)), a.win)
}

func (a *App) installPopular(core Core) {
	a.withBusy(func() {
		repo, err := a.mgr.repo(core.Repo)
		if err != nil {
			a.mgr.logf("ERROR: %v", err)
			return
		}
		if err := a.mgr.installBoard(repo, core.Vendor, core.Arch, ""); err != nil {
			a.mgr.logf("ERROR: %v", err)
		} else {
			a.mgr.logf("Installed %s to hardware/%s/%s", core.Label, core.Vendor, core.Arch)
		}
	})
}

func (a *App) updateIndex() {
	a.withBusy(func() {
		if err := a.mgr.updateIndex(); err != nil {
			a.mgr.logf("ERROR: %v", err)
		}
	})
}

func (a *App) listInstalledLibraries() {
	a.withBusy(func() {
		items, err := a.mgr.listLibraries(false, "")
		if err != nil {
			a.mgr.logf("ERROR: %v", err)
			return
		}
		labels := make([]string, 0, len(items))
		names := make([]string, 0, len(items))
		for _, item := range items {
			p := strings.SplitN(item, "\t", 2)
			name := p[0]
			version := ""
			if len(p) > 1 {
				version = p[1]
			}
			labels = append(labels, fmt.Sprintf("%s — %s", name, version))
			names = append(names, name)
		}
		fyne.Do(func() {
			selectWidget := widget.NewSelect(labels, nil)
			if len(labels) > 0 {
				selectWidget.SetSelected(labels[0])
			}
			remove := widget.NewButton("Remove selected", func() {
				if selectWidget.Selected == "" {
					return
				}
				idx := 0
				for i, label := range labels {
					if label == selectWidget.Selected {
						idx = i
						break
					}
				}
				name := names[idx]
				dialog.ShowConfirm("Remove library", "Delete "+name+" from the sketchbook?", func(ok bool) {
					if !ok {
						return
					}
					a.withBusy(func() {
						if err := removeLibrary(a.mgr.Config, name); err != nil {
							a.mgr.logf("ERROR: %v", err)
						} else {
							a.mgr.logf("Removed library %s", name)
						}
					})
				}, a.win)
			})
			body := container.NewVBox(widget.NewLabel(fmt.Sprintf("%d installed library folders", len(labels))), selectWidget, remove)
			dialog.ShowCustom("Installed libraries", "Close", body, a.win)
		})
	})
}

func (a *App) listInstalledBoards() {
	boards := a.mgr.listBoards()
	if len(boards) == 0 {
		dialog.ShowInformation("Installed boards", "No board cores found.", a.win)
		return
	}
	selectWidget := widget.NewSelect(boards, nil)
	selectWidget.SetSelected(boards[0])
	remove := widget.NewButton("Remove selected", func() {
		parts := strings.SplitN(selectWidget.Selected, string(os.PathSeparator), 2)
		if len(parts) != 2 {
			return
		}
		dialog.ShowConfirm("Remove board core", "Delete hardware/"+parts[0]+"/"+parts[1]+"?", func(ok bool) {
			if !ok {
				return
			}
			a.withBusy(func() {
				if err := removeBoard(a.mgr.Config, parts[0], parts[1]); err != nil {
					a.mgr.logf("ERROR: %v", err)
				} else {
					a.mgr.logf("Removed board %s/%s", parts[0], parts[1])
				}
			})
		}, a.win)
	})
	setup := widget.NewButton("Setup compiler tools", func() {
		parts := strings.SplitN(selectWidget.Selected, string(os.PathSeparator), 2)
		if len(parts) != 2 {
			return
		}
		a.withBusy(func() {
			if err := a.mgr.setupBoard(parts[0], parts[1]); err != nil {
				a.mgr.logf("ERROR: %v", err)
			} else {
				a.mgr.logf("Board setup completed: %s/%s", parts[0], parts[1])
			}
		})
	})
	body := container.NewVBox(widget.NewLabel(fmt.Sprintf("%d installed board cores", len(boards))), selectWidget, container.NewHBox(setup, remove))
	dialog.ShowCustom("Installed board cores", "Close", body, a.win)
}

func (a *App) showConfig() {
	c := a.mgr.Config
	sketch := widget.NewEntry()
	sketch.SetText(c.Sketchbook)
	data := widget.NewEntry()
	data.SetText(c.ArduinoData)
	save := widget.NewButton("Save configuration", func() {
		newCfg := c
		newCfg.Sketchbook = sketch.Text
		newCfg.ArduinoData = data.Text
		if err := saveConfig(newCfg); err != nil {
			dialog.ShowError(err, a.win)
			return
		}
		a.mgr.Config = newCfg
		a.appendLog("Configuration saved to " + newCfg.ConfigFile)
		dialog.ShowInformation("Configuration", "Saved.", a.win)
	})
	body := container.NewVBox(
		widget.NewLabel("Sketchbook Path"), sketch,
		widget.NewLabel("Arduino Data Dir"), data,
		widget.NewLabel("Libraries Dir: "+c.LibDir()),
		widget.NewLabel("Hardware Dir: "+c.HardwareDir()),
		widget.NewLabel("Index: "+c.IndexFile()),
		widget.NewLabel("Config: "+c.ConfigFile),
		save,
	)
	dialog.ShowCustom("Configuration", "Close", body, a.win)
}

func (a *App) importIndexDialog() {
	pathEntry := widget.NewEntry()
	pathEntry.SetPlaceHolder("/path/to/library_index.json")
	importBtn := widget.NewButton("Import", func() {
		path := strings.TrimSpace(pathEntry.Text)
		if path == "" {
			return
		}
		a.withBusy(func() {
			data, err := os.ReadFile(path)
			if err != nil {
				a.mgr.logf("ERROR: %v", err)
				return
			}
			var idx LibraryIndex
			if err := json.Unmarshal(data, &idx); err != nil {
				a.mgr.logf("ERROR: invalid index: %v", err)
				return
			}
			if err := os.MkdirAll(filepath.Dir(a.mgr.Config.IndexFile()), 0o755); err != nil {
				a.mgr.logf("ERROR: %v", err)
				return
			}
			if err := os.WriteFile(a.mgr.Config.IndexFile(), data, 0o644); err != nil {
				a.mgr.logf("ERROR: %v", err)
				return
			}
			a.mgr.logf("Imported library index: %d libraries", len(idx.Libraries))
		})
	})
	dialog.ShowCustom("Import library index", "Close", container.NewVBox(widget.NewLabel("JSON file path"), pathEntry, importBtn), a.win)
}

func (a *App) installRepoDialog() {
	repoEntry := widget.NewEntry()
	repoEntry.SetPlaceHolder("owner/repository")
	installBtn := widget.NewButton("Resolve and install", func() {
		name := strings.TrimSpace(repoEntry.Text)
		if name == "" {
			return
		}
		a.withBusy(func() {
			repo, err := a.mgr.repo(name)
			if err != nil {
				a.mgr.logf("ERROR: %v", err)
				return
			}
			if a.mode == "Boards" {
				vendor, arch := guessBoardNames(repo.FullName)
				if err := a.mgr.installBoard(repo, vendor, arch, ""); err != nil {
					a.mgr.logf("ERROR: %v", err)
				} else {
					a.mgr.logf("Installed board %s -> hardware/%s/%s", repo.FullName, vendor, arch)
				}
			} else {
				if err := a.mgr.installLibraryGit(repo); err != nil {
					a.mgr.logf("ERROR: %v", err)
				} else {
					a.mgr.logf("Installed library %s", repo.FullName)
				}
			}
		})
	})
	dialog.ShowCustom("Install exact GitHub repository", "Close", container.NewVBox(widget.NewLabel("owner/repository"), repoEntry, installBtn), a.win)
}

func (a *App) appendLog(s string) {
	if s == "" {
		return
	}
	stamp := time.Now().Format("15:04:05")
	text := strings.TrimRight(a.logBox.Text, "\n")
	if text == "" {
		text = fmt.Sprintf("[%s] %s", stamp, s)
	} else {
		text += fmt.Sprintf("\n[%s] %s", stamp, s)
	}
	a.logBox.SetText(text)
	// MultiLineEntry does not expose a portable scroll-to-end API in every Fyne release;
	// keeping focus here makes the latest operation visible after user interaction.
}

func main() {
	a := newApp()
	a.win.ShowAndRun()
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