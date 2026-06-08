// Package storage persists uploaded files to the local filesystem.
package storage

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
)

// allowedExt is the whitelist of image extensions we accept for uploads.
var allowedExt = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".gif":  true,
	".webp": true,
}

// Storage saves files under a base directory and returns web-relative paths.
type Storage struct {
	dir string
}

// New creates the upload directory if needed and returns a Storage.
func New(dir string) (*Storage, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, fmt.Errorf("create upload dir: %w", err)
	}
	return &Storage{dir: dir}, nil
}

// Save writes the uploaded file to disk under a collision-proof name and returns
// the relative URL path (e.g. "/uploads/<uuid>.jpg") to store in the database.
func (s *Storage) Save(file multipart.File, header *multipart.FileHeader) (string, error) {
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !allowedExt[ext] {
		return "", fmt.Errorf("unsupported file type %q", ext)
	}

	name := uuid.New().String() + ext
	dst, err := os.Create(filepath.Join(s.dir, name))
	if err != nil {
		return "", fmt.Errorf("create file: %w", err)
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		return "", fmt.Errorf("write file: %w", err)
	}

	return "/uploads/" + name, nil
}
