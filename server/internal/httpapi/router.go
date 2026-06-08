package httpapi

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

// Router builds the chi router with all routes and global middleware.
func (s *Server) Router() http.Handler {
	r := chi.NewRouter()

	// Global middleware: request IDs, real client IP, structured logging,
	// panic recovery, and permissive CORS for the mobile client.
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Authorization", "Content-Type"},
		AllowCredentials: false,
	}))

	r.Get("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})

	// Serve uploaded photos statically.
	fileServer := http.FileServer(http.Dir(s.cfg.UploadDir))
	r.Handle("/uploads/*", http.StripPrefix("/uploads/", fileServer))

	// --- Public routes ---
	r.Route("/auth", func(r chi.Router) {
		r.Post("/register", s.handleRegister)
		r.Post("/login", s.handleLogin)
	})

	r.Route("/search", func(r chi.Router) {
		r.Get("/users", s.handleSearchUsers)
		r.Get("/drinks", s.handleSearchDrinks)
		r.Get("/allDrinks", s.handleAllDrinks)
	})

	r.Route("/users", func(r chi.Router) {
		r.Get("/topUsers", s.handleTopUsers)
		r.Get("/{id}", s.handleGetUser)
		r.Get("/{id}/followers", s.handleFollowers)
		r.Get("/{id}/following", s.handleFollowing)
		r.Get("/{id}/following/reviews", s.handleFollowingReviews)

		// Protected sub-group.
		r.Group(func(r chi.Router) {
			r.Use(RequireAuth(s.cfg.JWTSecret))
			r.Put("/{id}", s.handleUpdateUser)
			r.Post("/{id}/follow", s.handleFollow)
			r.Post("/{id}/unfollow", s.handleUnfollow)
		})
	})

	r.Route("/reviews", func(r chi.Router) {
		r.Get("/", s.handleListReviews)
		r.Get("/drink", s.handleReviewsByDrink)
		r.Get("/mostReviewedDrinks", s.handleMostReviewedDrinks)

		r.Group(func(r chi.Router) {
			r.Use(RequireAuth(s.cfg.JWTSecret))
			r.Post("/", s.handleCreateReview)
		})
	})

	return r
}
