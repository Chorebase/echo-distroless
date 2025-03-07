# Echo Distroless

A minimal Docker container based on the distroless image that runs the `echo` binary, supporting both x86-64 (AMD64) and ARM64 architectures.

## Overview

This project creates a minimal Docker container using Google's distroless images with automatic host architecture detection and cross-architecture build support.

## Project Structure

- `Dockerfile` - Multi-stage build that compiles the echo binary for both architectures and creates distroless images.
- `echo.c` - Source code for a simple echo implementation.
- `Makefile` - Contains commands to build and run the project for multiple architectures.

## Prerequisites

For cross-architecture builds (e.g., building ARM64 images on an AMD64 host or vice versa), QEMU emulation is required. The Makefile includes automatic detection of the host architecture and will set up QEMU as needed.

```bash
# Set up QEMU manually if needed
make setup-qemu
```

## Build Instructions

### Building the Docker Image

The Makefile automatically detects your host architecture and optimizes builds accordingly:

```bash
# For AMD64 (x86-64) only
make build-amd64

# For ARM64 (AArch64) only
make build-arm64

# For all architectures (recommended)
make build-all
```

When building for your native architecture, no emulation is used, resulting in faster builds. When building for a different architecture, QEMU will be set up automatically.

### Creating Multi-Architecture Images

To create a multi-architecture manifest:

```bash
make manifest
```

This will create a manifest that includes both the AMD64 and ARM64 variants.

### Publishing Multi-Architecture Images

To push the multi-architecture manifest to a registry:

```bash
# Optionally set the registry first
# REGISTRY=your-registry.com make push
make push
```

## Running the Container

You can run the container with architecture-specific images or using the multi-architecture manifest:

```bash
# Run using the multi-architecture manifest (Docker will select the appropriate image)
make run ARGS="Hello World"

# Run specifically on AMD64
make run-amd64 ARGS="Hello from AMD64"

# Run specifically on ARM64
make run-arm64 ARGS="Hello from ARM64"
```

This will output the message you provided in the ARGS parameter.

## Cleaning Up

To remove the built Docker images:

```bash
make clean
```

## Help

For a list of available commands and information about your host architecture:

```bash
make help
```
