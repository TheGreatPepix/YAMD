package gui

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"

	"ymd/internal/yam"
)

const (
	minConcurrency     = 1
	maxConcurrency     = 8
	defaultConcurrency = 4
)

type config struct {
	Dir         string `json:"dir"`
	Theme       string `json:"theme"`
	Quality     string `json:"quality"`
	Concurrency int    `json:"concurrency"`

	Token string `json:"token,omitempty"`
}

func defaultDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		return ""
	}
	return filepath.Join(home, "Music", "Yandex Music Downloads")
}

func defaultConfig() config {
	return config{
		Dir:         defaultDir(),
		Theme:       "dark",
		Quality:     string(yam.Lossless),
		Concurrency: defaultConcurrency,
	}
}

func configPath() string {
	dir, err := os.UserConfigDir()
	if err != nil || dir == "" {
		dir = os.TempDir()
	}
	return filepath.Join(dir, "ymd", "config.json")
}

func loadConfig() config {
	c := defaultConfig()
	if b, err := os.ReadFile(configPath()); err == nil {
		var saved config
		if json.Unmarshal(b, &saved) == nil {
			if saved.Dir != "" {
				c.Dir = saved.Dir
			}
			if saved.Theme != "" {
				c.Theme = saved.Theme
			}
			if saved.Quality == string(yam.MP3) {
				c.Quality = saved.Quality
			}
			if saved.Concurrency != 0 {
				c.Concurrency = clampConcurrency(saved.Concurrency)
			}
			c.Token = saved.Token
		}
	}
	return c
}

func clampConcurrency(n int) int {
	return max(minConcurrency, min(maxConcurrency, n))
}

func (c config) quality() yam.Quality {
	if c.Quality == string(yam.MP3) {
		return yam.MP3
	}
	return yam.Lossless
}

func (c config) token() string {
	if c.Token == "" {
		return ""
	}
	sealed, err := base64.StdEncoding.DecodeString(c.Token)
	if err != nil {
		return ""
	}
	plain, err := unprotect(sealed)
	if err != nil {
		return ""
	}
	return string(plain)
}

func (c *config) setToken(token string) error {
	if token == "" {
		c.Token = ""
		return nil
	}
	sealed, err := protect([]byte(token))
	if err != nil {
		return err
	}
	c.Token = base64.StdEncoding.EncodeToString(sealed)
	return nil
}

func (c config) save() error {
	path := configPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
