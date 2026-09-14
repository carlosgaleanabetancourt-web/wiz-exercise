package main

import (
	"net/http"

	controller "github.com/jeffthorne/tasky/controllers"
	"github.com/jeffthorne/tasky/middleware"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func index(c *gin.Context) {
	c.HTML(http.StatusOK, "login.html", nil)
}

func securityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "0")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		c.Header("Content-Security-Policy",
			"default-src 'self'; "+
				"script-src 'self' 'unsafe-inline'; "+
				"style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "+
				"font-src 'self' https://fonts.gstatic.com; "+
				"img-src 'self' data:; "+
				"connect-src 'self'")
		c.Next()
	}
}

func main() {
	godotenv.Overload()

	router := gin.Default()
	router.Use(securityHeaders())
	router.LoadHTMLGlob("assets/*.html")
	router.Static("/assets", "./assets")

	router.GET("/", index)
	router.GET("/todos/:userid", controller.GetTodos)
	router.GET("/todo/:id", controller.GetTodo)
	router.POST("/todo/:userid", controller.AddTodo)
	router.DELETE("/todo/:userid/:id", controller.DeleteTodo)
	router.DELETE("/todos/:userid", controller.ClearAll)
	router.PUT("/todo", controller.UpdateTodo)

	authLimiter := middleware.RateLimiter()
	router.POST("/signup", authLimiter, controller.SignUp)
	router.POST("/login", authLimiter, controller.Login)
	router.GET("/logout", controller.Logout)
	router.GET("/todo", controller.Todo)

	router.Run(":8080")
}
