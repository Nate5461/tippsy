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

	// --- Public routes: only auth and the health check ---
	r.Route("/auth", func(r chi.Router) {
		r.Post("/register", s.handleRegister)
		r.Post("/login", s.handleLogin)
		r.Post("/verify-email", s.handleVerifyEmail)
		r.Post("/resend-verification", s.handleResendVerification)
	})

	// --- Protected routes: everything else requires a valid token ---
	r.Group(func(r chi.Router) {
		r.Use(RequireAuth(s.cfg.JWTSecret))

		// Serve uploaded photos statically. The client must send its
		// Authorization header on image requests too.
		fileServer := http.FileServer(http.Dir(s.cfg.UploadDir))
		r.Handle("/uploads/*", http.StripPrefix("/uploads/", fileServer))

		r.Route("/search", func(r chi.Router) {
			r.Get("/users", s.handleSearchUsers)
		})

		r.Get("/units", s.handleListUnits)
		r.Get("/glasses", s.handleListGlasses)

		// Ingredient search results include the caller's custom ingredients.
		r.Route("/ingredients", func(r chi.Router) {
			r.Get("/", s.handleSearchIngredients)
			r.Post("/", s.handleCreateIngredient)
		})

		r.Route("/recipes", func(r chi.Router) {
			r.Get("/", s.handleSearchRecipes)
			r.Post("/", s.handleCreateRecipe)
			r.Get("/{id}", s.handleGetRecipe)
			r.Put("/{id}", s.handleUpdateRecipe)
			r.Delete("/{id}", s.handleDeleteRecipe)
			r.Get("/{id}/reviews", s.handleRecipeReviews)
			r.Post("/{id}/favourite", s.handleAddFavourite)
			r.Delete("/{id}/favourite", s.handleRemoveFavourite)
		})

		r.Route("/users", func(r chi.Router) {
			r.Get("/topUsers", s.handleTopUsers)
			r.Get("/{id}", s.handleGetUser)
			r.Put("/{id}", s.handleUpdateUser)
			r.Get("/{id}/followers", s.handleFollowers)
			r.Get("/{id}/following", s.handleFollowing)
			r.Get("/{id}/following/reviews", s.handleFollowingReviews)
			r.Get("/{id}/favourites", s.handleListFavourites)
			r.Post("/{id}/follow", s.handleFollow)
			r.Post("/{id}/unfollow", s.handleUnfollow)

			// Personal: the bar and the menu it can make.
			r.Get("/{id}/bar", s.handleListBar)
			r.Post("/{id}/bar", s.handleAddBarItem)
			r.Delete("/{id}/bar/{ingredientId}", s.handleRemoveBarItem)
			r.Get("/{id}/menu", s.handleMyMenu)
		})

		r.Route("/reviews", func(r chi.Router) {
			r.Get("/", s.handleListReviews)
			r.Post("/", s.handleCreateReview)
		})
	})

	return r
}
