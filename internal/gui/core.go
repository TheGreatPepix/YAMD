package gui

import (
	"bufio"
	"encoding/json"
	"io"
	"log"
	"sync"
)

const maxCommand = 16 << 20

type coreHost struct {
	outMu sync.Mutex
	out   io.Writer

	queueMu sync.Mutex
	queue   []func()
	wake    chan struct{}
	done    chan struct{}
	exiting sync.Once
}

func newCoreHost(out io.Writer) *coreHost {
	return &coreHost{out: out, wake: make(chan struct{}, 1), done: make(chan struct{})}
}

func (h *coreHost) loop() {
	for {
		select {
		case <-h.wake:
		case <-h.done:
			return
		}
		h.queueMu.Lock()
		q := h.queue
		h.queue = nil
		h.queueMu.Unlock()
		for _, f := range q {
			f()
		}
	}
}

func (h *coreHost) post(f func()) {
	h.queueMu.Lock()
	h.queue = append(h.queue, f)
	h.queueMu.Unlock()
	select {
	case h.wake <- struct{}{}:
	default:
	}
}

func (h *coreHost) send(event []byte) {
	h.outMu.Lock()
	defer h.outMu.Unlock()
	_, _ = h.out.Write(append(append([]byte(nil), event...), '\n'))
}

func (h *coreHost) sendEvent(event any) {
	if data, err := json.Marshal(event); err == nil {
		h.send(data)
	}
}

func (h *coreHost) exit() {
	h.exiting.Do(func() {
		h.sendEvent(map[string]any{"type": "exit"})
		close(h.done)
	})
}

func RunCore(in io.Reader, out io.Writer) int {
	h := newCoreHost(out)
	g := newApp()
	g.host = h
	g.start()
	go h.read(in, g)
	h.loop()
	return 0
}

func (h *coreHost) read(in io.Reader, g *App) {
	lines := bufio.NewScanner(in)
	lines.Buffer(make([]byte, 64<<10), maxCommand)
	for lines.Scan() {
		line := lines.Text()
		var c struct {
			Cmd string `json:"cmd"`
		}
		if json.Unmarshal([]byte(line), &c) != nil || c.Cmd == "" {
			continue
		}
		h.post(func() { g.onMessage(line) })
	}
	if err := lines.Err(); err != nil {
		log.Print("Соединение с окном разорвано: ", err)
	}
	h.post(h.exit)
}
