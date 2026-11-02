package gui

type uiState struct {
	Type        string `json:"type"`
	Dir         string `json:"dir"`
	Theme       string `json:"theme"`
	Quality     string `json:"quality"`
	Concurrency int    `json:"concurrency"`
	Version     string `json:"version"`
	Log         string `json:"log,omitempty"`
}

func (g *App) emitState(withLog bool) {
	g.mu.Lock()
	s := uiState{
		Type:        "state",
		Dir:         g.cfg.Dir,
		Theme:       g.cfg.Theme,
		Quality:     string(g.cfg.quality()),
		Concurrency: g.cfg.Concurrency,
		Version:     Version,
	}
	g.mu.Unlock()
	if withLog {
		s.Log = g.logs.String()
	}
	g.emit(s)
}
