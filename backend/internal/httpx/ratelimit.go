package httpx

import (
	"net"
	"net/http"
	"strconv"
	"sync"
	"time"
)

// RateLimiter is a fixed-window limiter keyed by client IP. It is in-memory,
// which matches the single-instance SQLite deployment; a multi-instance setup
// needs a shared store (see docs/review/05-future-risks.md).
type RateLimiter struct {
	limit  int
	window time.Duration

	mu      sync.Mutex
	buckets map[string]*bucket
	swept   time.Time
}

type bucket struct {
	count int
	reset time.Time
}

// NewRateLimiter allows `limit` requests per `window` for each client IP.
func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{limit: limit, window: window, buckets: make(map[string]*bucket)}
}

// Allow records one request for key and reports whether it is within the limit
// and, when it is not, how long until the window resets.
func (l *RateLimiter) Allow(key string) (bool, time.Duration) {
	now := time.Now()
	l.mu.Lock()
	defer l.mu.Unlock()

	// Sweep expired buckets at most once per window so the map stays bounded
	// by the number of clients seen in one window.
	if now.Sub(l.swept) > l.window {
		for k, b := range l.buckets {
			if now.After(b.reset) {
				delete(l.buckets, k)
			}
		}
		l.swept = now
	}

	b, ok := l.buckets[key]
	if !ok || now.After(b.reset) {
		b = &bucket{reset: now.Add(l.window)}
		l.buckets[key] = b
	}
	b.count++
	if b.count > l.limit {
		return false, b.reset.Sub(now)
	}
	return true, 0
}

// Middleware answers 429 once a client IP exceeds the limit.
func (l *RateLimiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ok, retry := l.Allow(ClientIP(r))
		if !ok {
			w.Header().Set("Retry-After", strconv.Itoa(int(retry.Seconds())+1))
			JSON(w, http.StatusTooManyRequests, map[string]string{
				"error":   "rate_limited",
				"message": "طلبات كتير في وقت قصير. حاول تاني بعد شوية.",
			})
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ClientIP is the peer address. X-Forwarded-For is deliberately ignored: it is
// client-controlled unless a trusted proxy rewrites it, and trusting it would
// let anyone pick their own rate-limit bucket.
func ClientIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
