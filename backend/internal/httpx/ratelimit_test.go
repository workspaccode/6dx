package httpx

import (
	"net"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRateLimiterBlocksAfterLimitAndResets(t *testing.T) {
	l := NewRateLimiter(2, 50*time.Millisecond)
	for i := 0; i < 2; i++ {
		if ok, _ := l.Allow("1.2.3.4"); !ok {
			t.Fatalf("request %d must pass", i+1)
		}
	}
	if ok, _ := l.Allow("1.2.3.4"); ok {
		t.Fatal("third request in the window must be limited")
	}
	if ok, _ := l.Allow("5.6.7.8"); !ok {
		t.Fatal("another client has its own bucket")
	}
	time.Sleep(60 * time.Millisecond)
	if ok, _ := l.Allow("1.2.3.4"); !ok {
		t.Fatal("the window must reset")
	}
}

func cidr(t *testing.T, s string) *net.IPNet {
	t.Helper()
	_, n, err := net.ParseCIDR(s)
	if err != nil {
		t.Fatal(err)
	}
	return n
}

func TestClientIPWithoutProxiesIsThePeer(t *testing.T) {
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "203.0.113.7:5555"
	r.Header.Set("X-Forwarded-For", "1.1.1.1")
	if got := (ClientIPResolver{}).ClientIP(r); got != "203.0.113.7" {
		t.Fatalf("got %q: X-Forwarded-For must be ignored without trusted proxies", got)
	}
}

func TestClientIPBehindATrustedProxy(t *testing.T) {
	resolver := ClientIPResolver{Trusted: []*net.IPNet{cidr(t, "10.0.0.0/8")}}
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "10.0.0.2:443"
	// The client forged the first entry; the proxy appended the real one.
	r.Header.Set("X-Forwarded-For", "6.6.6.6, 198.51.100.20")
	if got := resolver.ClientIP(r); got != "198.51.100.20" {
		t.Fatalf("got %q, want the address the proxy saw", got)
	}
}

func TestClientIPIgnoresTheHeaderFromAnUntrustedPeer(t *testing.T) {
	resolver := ClientIPResolver{Trusted: []*net.IPNet{cidr(t, "10.0.0.0/8")}}
	r := httptest.NewRequest("GET", "/", nil)
	r.RemoteAddr = "203.0.113.9:1234"
	r.Header.Set("X-Forwarded-For", "198.51.100.20")
	if got := resolver.ClientIP(r); got != "203.0.113.9" {
		t.Fatalf("got %q: a direct client must not pick its own address", got)
	}
}
