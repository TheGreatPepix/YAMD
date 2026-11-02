package gui

import (
	"encoding/json"
	"net/url"
	"regexp"
	"strings"

	"ymd/internal/yam"
)

type uiCommand struct {
	Cmd         string `json:"cmd"`
	Token       string `json:"token"`
	Link        string `json:"link"`
	Dir         string `json:"dir"`
	Theme       string `json:"theme"`
	Quality     string `json:"quality"`
	Concurrency int    `json:"concurrency"`
	ID          int    `json:"id"`
	Album       string `json:"album"`
	Select      []struct {
		Album  string   `json:"album"`
		Tracks []string `json:"tracks"`
	} `json:"select"`
}

func (g *App) onMessage(message string) {
	var c uiCommand
	if err := json.Unmarshal([]byte(message), &c); err != nil {
		return
	}
	switch c.Cmd {
	case "ready":
		g.emitState(true)
		g.mu.Lock()
		acc := g.account
		g.mu.Unlock()
		g.emit(acc)
		g.jobs.emitAll()
	case "login":
		token := extractToken(c.Token)
		if token == "" {
			g.notice("Вставьте токен Яндекс Музыки", "error")
			return
		}
		g.checkAccount(token, true)
	case "recheck":
		g.recheck()
	case "logout":
		g.logout()
	case "prefs":
		g.setPrefs(c)
	case "preview":
		g.preview(strings.TrimSpace(c.Link))
	case "download":
		var sel yam.Selection
		if len(c.Select) > 0 {
			sel = yam.Selection{}
			for _, s := range c.Select {
				sel[s.Album] = s.Tracks
			}
		}
		g.startDownload(strings.TrimSpace(c.Link), strings.TrimSpace(c.Dir), sel)
	case "album":
		g.albumTracks(c.Album)
	case "cancel":
		g.jobs.cancel(c.ID)
	case "retry":
		g.retry(c.ID)
	case "remove":
		g.jobs.remove(c.ID)
	case "exit":
		g.jobs.cancel(0)
		g.host.post(g.host.exit)
	}
}

var accessTokenRe = regexp.MustCompile(`access_token=([^&#\s]+)`)

func extractToken(s string) string {
	s = strings.TrimSpace(s)
	if m := accessTokenRe.FindStringSubmatch(s); m != nil {
		if t, err := url.QueryUnescape(m[1]); err == nil {
			return t
		}
		return m[1]
	}
	return s
}

func (g *App) setPrefs(c uiCommand) {
	g.mu.Lock()
	if c.Dir != "" {
		g.cfg.Dir = c.Dir
	}
	if c.Theme != "" {
		g.cfg.Theme = c.Theme
	}
	if c.Quality != "" {
		g.cfg.Quality = c.Quality
		g.cfg.Quality = string(g.cfg.quality())
	}
	if c.Concurrency != 0 {
		g.cfg.Concurrency = clampConcurrency(c.Concurrency)
		g.jobs.gate.setLimit(g.cfg.Concurrency)
	}
	err := g.cfg.save()
	g.mu.Unlock()
	if err != nil {
		g.notice("Не удалось сохранить настройки: "+err.Error(), "error")
	}
	g.emitState(false)
}
