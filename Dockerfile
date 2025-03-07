# Multi-stage build for amd64 and arm64 architectures

# Common base stage with shared settings
FROM alpine:3.19 AS builder-base
RUN apk add --no-cache gcc musl-dev
WORKDIR /build
COPY echo.c .

# AMD64 builder stage
FROM --platform=linux/amd64 builder-base AS builder-amd64
RUN gcc -O2 -o echo echo.c -static

# ARM64 builder stage
FROM --platform=linux/arm64 builder-base AS builder-arm64
RUN gcc -O2 -o echo echo.c -static

# Final amd64 stage
FROM --platform=linux/amd64 gcr.io/distroless/static-debian12:nonroot AS final-amd64
COPY --from=builder-amd64 /build/echo /echo
ENTRYPOINT ["/echo"]

# Final arm64 stage
FROM --platform=linux/arm64 gcr.io/distroless/static-debian12:nonroot AS final-arm64
COPY --from=builder-arm64 /build/echo /echo
ENTRYPOINT ["/echo"]

# Use ARG to select the target architecture
ARG TARGETARCH
FROM final-${TARGETARCH} AS final
# Entrypoint is inherited from the base images