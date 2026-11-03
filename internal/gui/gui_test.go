package gui

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"ymd/internal/yam"
)

func TestGateLimit(t *testing.T) {
	g := newGate(3)
	var active, peak atomic.Int32
	var wg sync.WaitGroup
	for range 20 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := g.acquire(context.Background()); err != nil {
				t.Error(err)
				return
			}
			n := active.Add(1)
			for {
				p := peak.Load()
				if n <= p || peak.CompareAndSwap(p, n) {
					break
				}
			}
			time.Sleep(5 * time.Millisecond)
			active.Add(-1)
			g.release()
		}()
	}
	wg.Wait()
	if p := peak.Load(); p != 3 {
		t.Errorf("пик одновременных = %d, want 3", p)
	}
}

func TestGateCancelAndResize(t *testing.T) {
	g := newGate(1)
	if err := g.acquire(context.Background()); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	errc := make(chan error)
	go func() { errc <- g.acquire(ctx) }()
	cancel()
	if err := <-errc; err == nil {
		t.Fatal("отменённое ожидание получило слот")
	}

	got := make(chan struct{})
	go func() {
		_ = g.acquire(context.Background())
		close(got)
	}()
	time.Sleep(10 * time.Millisecond)
	g.setLimit(2)
	select {
	case <-got:
	case <-time.After(time.Second):
		t.Fatal("ждущий не получил слот после увеличения лимита")
	}
}

func TestExtractToken(t *testing.T) {
	cases := map[string]string{
		"  y0_AgAAAAB-abc  ": "y0_AgAAAAB-abc",
		"https://music.yandex.ru/#access_token=y0_AgAA-xyz&token_type=bearer&expires_in=31535645": "y0_AgAA-xyz",
		"https://oauth.yandex.ru/verification_code#access_token=AQAAAA123&state=":                 "AQAAAA123",
	}
	for in, want := range cases {
		if got := extractToken(in); got != want {
			t.Errorf("extractToken(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestProtectRoundTrip(t *testing.T) {
	secret := []byte("y0_AgAAAAB-test-token")
	sealed, err := protect(secret)
	if err != nil {
		t.Fatal(err)
	}
	plain, err := unprotect(sealed)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(plain, secret) {
		t.Errorf("unprotect = %q", plain)
	}

	var c config
	if err := c.setToken(string(secret)); err != nil {
		t.Fatal(err)
	}
	if c.token() != string(secret) {
		t.Errorf("config.token() не восстановил токен")
	}
	if bytes.Contains([]byte(c.Token), secret) {
		t.Errorf("токен лежит в конфиге открытым текстом")
	}
}

func TestSearchError(t *testing.T) {
	cases := map[error]string{
		errors.New(`Get "https://api.music.yandex.net/search": dial tcp: no such host`): "Нет связи с Яндекс Музыкой. Проверьте подключение и повторите.",
		fmt.Errorf("x: %w", context.DeadlineExceeded):                                   "Яндекс Музыка не ответила вовремя. Проверьте подключение и повторите.",
		&yam.APIError{Status: 500}:                                                      "Яндекс Музыка ответила ошибкой (HTTP 500). Повторите чуть позже.",
		yam.ErrUnauthorized:                                                             yam.ErrUnauthorized.Error(),
	}
	for err, want := range cases {
		if got := searchError(err); got != want {
			t.Errorf("searchError(%v) = %q, want %q", err, got, want)
		}
	}
}
