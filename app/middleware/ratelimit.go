package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
)

type visitor struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

var (
	visitors sync.Map
	once     sync.Once
)

func cleanupVisitors() {
	for {
		time.Sleep(5 * time.Minute)
		visitors.Range(func(key, value any) bool {
			v := value.(*visitor)
			if time.Since(v.lastSeen) > 5*time.Minute {
				visitors.Delete(key)
			}
			return true
		})
	}
}

func getVisitor(ip string) *rate.Limiter {
	once.Do(func() {
		go cleanupVisitors()
	})

	if v, exists := visitors.Load(ip); exists {
		entry := v.(*visitor)
		entry.lastSeen = time.Now()
		return entry.limiter
	}

	limiter := rate.NewLimiter(rate.Every(time.Minute/5), 5)
	visitors.Store(ip, &visitor{limiter: limiter, lastSeen: time.Now()})
	return limiter
}

func RateLimiter() gin.HandlerFunc {
	return func(c *gin.Context) {
		limiter := getVisitor(c.ClientIP())
		if !limiter.Allow() {
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "too many requests, please try again later"})
			c.Abort()
			return
		}
		c.Next()
	}
}
