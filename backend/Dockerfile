# Build stage
FROM golang:1.27-alpine AS build

WORKDIR /src

# Dependencies first: this layer is cached until go.mod/go.sum change.
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# Runtime stage
FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata wget sqlite && \
    adduser -D -u 10001 app

COPY --from=build /out/api /usr/local/bin/api

USER app
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/usr/local/bin/api"]
