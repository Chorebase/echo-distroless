# Variables
IMAGE_NAME := echo-distroless
IMAGE_TAG := 1.0.0
REGISTRY := # Set this if pushing to a registry

# Architecture specific tags
AMD64_TAG := $(IMAGE_TAG)-amd64
ARM64_TAG := $(IMAGE_TAG)-arm64

# Detect host architecture
HOST_ARCH := $(shell uname -m)
ifeq ($(HOST_ARCH),x86_64)
    HOST_PLATFORM := linux/amd64
    HOST_TAG := $(AMD64_TAG)
    CROSS_PLATFORM := linux/arm64
    CROSS_TAG := $(ARM64_TAG)
else ifeq ($(HOST_ARCH),aarch64)
    HOST_PLATFORM := linux/arm64
    HOST_TAG := $(ARM64_TAG)
    CROSS_PLATFORM := linux/amd64
    CROSS_TAG := $(AMD64_TAG)
else
    $(error Unsupported architecture: $(HOST_ARCH))
endif

# Default target
.PHONY: all
all: build-all

# Setup QEMU for multi-architecture builds (only when needed)
.PHONY: setup-qemu
setup-qemu:
	@echo "Checking if QEMU setup is needed for cross-architecture builds..."
	@if ! docker buildx inspect | grep -q $(CROSS_PLATFORM); then \
		echo "Setting up QEMU for cross-architecture builds"; \
		docker run --privileged --rm tonistiigi/binfmt:latest --install all; \
	else \
		echo "QEMU already configured for $(CROSS_PLATFORM)"; \
	fi

# Build the Docker image for native architecture (no emulation needed)
.PHONY: build-native
build-native:
	@echo "Building for native architecture ($(HOST_PLATFORM))"
	docker build --platform $(HOST_PLATFORM) \
      --build-arg TARGETARCH=$(subst linux/,,$(HOST_PLATFORM)) \
      --build-arg http_proxy="$(http_proxy)" \
      --build-arg https_proxy="$(https_proxy)" \
      --build-arg no_proxy="$(no_proxy)" \
      -t $(IMAGE_NAME):$(HOST_TAG) .
	@echo "Built $(IMAGE_NAME):$(HOST_TAG)"

# Build the Docker image for cross architecture (with emulation)
.PHONY: build-cross
build-cross: setup-qemu
	@echo "Building for cross architecture ($(CROSS_PLATFORM))"
	docker build --platform $(CROSS_PLATFORM) \
      --build-arg TARGETARCH=$(subst linux/,,$(CROSS_PLATFORM)) \
      --build-arg http_proxy="$(http_proxy)" \
      --build-arg https_proxy="$(https_proxy)" \
      --build-arg no_proxy="$(no_proxy)" \
      -t $(IMAGE_NAME):$(CROSS_TAG) .
	@echo "Built $(IMAGE_NAME):$(CROSS_TAG)"

# Build the Docker image for amd64
.PHONY: build-amd64
build-amd64:
	@if [ "$(HOST_ARCH)" = "x86_64" ]; then \
		$(MAKE) build-native; \
	else \
		$(MAKE) build-cross; \
	fi

# Build the Docker image for arm64
.PHONY: build-arm64
build-arm64:
	@if [ "$(HOST_ARCH)" = "aarch64" ]; then \
		$(MAKE) build-native; \
	else \
		$(MAKE) build-cross; \
	fi

# Build for all architectures
.PHONY: build-all
build-all: build-amd64 build-arm64
	@echo "Built images for all supported architectures"

# Create a multi-architecture manifest
.PHONY: manifest
manifest: build-all
	docker manifest create $(IMAGE_NAME):$(IMAGE_TAG) \
		$(IMAGE_NAME):$(AMD64_TAG) \
		$(IMAGE_NAME):$(ARM64_TAG)
	@echo "Created multi-architecture manifest $(IMAGE_NAME):$(IMAGE_TAG)"

# Push the multi-architecture manifest to a registry
.PHONY: push
push: manifest
	docker manifest push $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "Pushed multi-architecture manifest $(IMAGE_NAME):$(IMAGE_TAG)"

# Run the Docker image for AMD64 architecture
.PHONY: run-amd64
run-amd64:
	@if [ "$(HOST_ARCH)" != "x86_64" ]; then $(MAKE) setup-qemu; fi
	@echo "Running $(IMAGE_NAME):$(AMD64_TAG) (AMD64) with arguments: $(ARGS)"
	docker run --platform linux/amd64 --rm $(IMAGE_NAME):$(AMD64_TAG) $(ARGS)

# Run the Docker image for ARM64 architecture
.PHONY: run-arm64
run-arm64:
	@if [ "$(HOST_ARCH)" != "aarch64" ]; then $(MAKE) setup-qemu; fi
	@echo "Running $(IMAGE_NAME):$(ARM64_TAG) (ARM64) with arguments: $(ARGS)"
	docker run --platform linux/arm64 --rm $(IMAGE_NAME):$(ARM64_TAG) $(ARGS)

# Run the Docker image with multi-arch manifest
.PHONY: run
run: manifest
	@echo "Running $(IMAGE_NAME):$(IMAGE_TAG) with arguments: $(ARGS)"
	docker run --rm $(IMAGE_NAME):$(IMAGE_TAG) $(ARGS)

# Clean target to remove the Docker images
.PHONY: clean
clean:
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	docker rmi $(IMAGE_NAME):$(AMD64_TAG) $(IMAGE_NAME):$(ARM64_TAG) || true
	@echo "Removed all built Docker images"

# Help target
.PHONY: help
help:
	@echo "Host architecture: $(HOST_ARCH) ($(HOST_PLATFORM))"
	@echo "Available targets:"
	@echo "  all          : Default target, builds Docker images for all architectures"
	@echo "  build-native : Build for the native architecture ($(HOST_PLATFORM))"
	@echo "  build-cross  : Build for the cross architecture ($(CROSS_PLATFORM))"
	@echo "  build-amd64  : Build the Docker image for amd64 architecture"
	@echo "  build-arm64  : Build the Docker image for arm64 architecture"
	@echo "  build-all    : Build Docker images for all supported architectures"
	@echo "  manifest     : Create multi-architecture manifest"
	@echo "  push         : Push multi-architecture manifest to registry"
	@echo "  run          : Run the Docker image with multi-arch manifest (use ARGS='your message' to pass arguments)"
	@echo "  run-amd64    : Run the Docker image for AMD64 architecture (use ARGS='your message' to pass arguments)"
	@echo "  run-arm64    : Run the Docker image for ARM64 architecture (use ARGS='your message' to pass arguments)" 
	@echo "  clean        : Remove the built Docker images"
	@echo "  help         : Show this help message"