# Dockerfile
# Start with a builder stage to compile the application
FROM golang:1.20-alpine AS builder

# Set CoreDNS version
ENV COREDNS_REPO=https://github.com/coredns/coredns.git
ENV COREDNS_TAG=v1.10.1

# Install Git and make
RUN apk add --no-cache git make

# Clone CoreDNS source
RUN git clone --depth 1 --branch ${COREDNS_TAG} ${COREDNS_REPO} /go/src/github.com/coredns/coredns
WORKDIR /go/src/github.com/coredns/coredns

# Copy the local iprewrite plugin source code into the CoreDNS source directory
COPY ./plugin/iprewrite ./plugin/iprewrite/

# Add iprewrite plugin to the plugin.cfg file - aligns the path to CoreDNS
RUN echo "iprewrite:github.com/TheRealKidMagic/coredns-isonetworking/plugin/iprewrite" >> plugin.cfg

# Crucial to realign the path relative to the Go build
RUN go mod edit -replace github.com/TheRealKidMagic/coredns-isonetworking/plugin/iprewrite=./plugin/iprewrite

# Run 'go mod tidy' to resolve and download dependencies for the plugin
RUN go mod tidy

#RUN go get gopkg.in/DataDog/dd-trace-go.v1@v1.44.0
RUN ls plugin/iprewrite && cat plugin.cfg && go mod tidy

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
