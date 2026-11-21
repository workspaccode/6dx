package httpx

import (
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
