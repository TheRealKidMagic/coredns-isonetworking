# Dockerfile
# Start with a builder stage to compile the application
FROM coredns/coredns-builder:latest as builder

# Set up working directory
WORKDIR /go/src/github.com/coredns/coredns

# Copy your plugin into place
COPY ./plugin/iprewrite ./plugin/iprewrite/

# Register plugin in plugin.cfg
RUN echo "iprewrite:github.com/TheRealKidMagic/coredns-isonetworking/plugin/iprewrite" >> plugin.cfg

# Insert import statement into the import block of main.go
RUN sed -i '/^import (/a\    _ "github.com/TheRealKidMagic/coredns-isonetworking/plugin/iprewrite"' main.go

# Run 'go mod tidy' to resolve and download dependencies for the plugin
RUN go mod tidy

# Build CoreDNS with iprewrite plugin
RUN make coredns

# Final Image
FROM alpine:3.18
RUN apk add --no-cache gettext

# Copy the compiled CoreDNS binary from the builder stage
COPY --from=builder /go/src/github.com/coredns/coredns/coredns /usr/local/bin/coredns

# Set up the working directory and copy necessary files for runtime
WORKDIR /etc/coredns
COPY Corefile.tmpl .
COPY entrypoint.sh .

# Make the entrypoint script executable
RUN chmod +x /etc/coredns/entrypoint.sh

ENTRYPOINT ["/etc/coredns/entrypoint.sh"]
