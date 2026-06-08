FROM golang:1.22-alpine AS builder

WORKDIR /app

# Install dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application statically
RUN CGO_ENABLED=0 GOOS=linux go build -o api ./cmd/api

# Runtime phase
FROM alpine:latest

WORKDIR /app

# Copy the pre-built binary
COPY --from=builder /app/api .

# Expose port (can be overridden by environment)
EXPOSE 8080

# Command to run
CMD ["./api"]
