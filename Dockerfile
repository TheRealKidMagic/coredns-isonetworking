# Dockerfile
# Start with a builder stage to compile the application
ARG GOLANG_VERS=1.23.9
ARG ALPINE_VERS=3.22.1

FROM golang:1.23.9-alpine as builder
# FROM golang:${GOLANG_VERS}-alpine${ALPINE_VERS} as builder

RUN apk add --no-cache gcc musl-dev git binutils
# RUN apk --no-cache add binutils 

ARG CGO_ENABLED=1
ARG PLUGIN_PRIO=50
ARG COREDNS_VERS=v1.12.2

# RUN go mod download github.com/coredns/coredns@v${COREDNS_VERS}
# WORKDIR $GOPATH/pkg/mod/github.com/coredns/coredns@v${COREDNS_VERS}
# RUN go mod download

WORKDIR /go/src/github.com/coredns/coredns
RUN git clone --branch ${COREDNS_VERS} https://github.com/coredns/coredns.git .

COPY . /plugin
# COPY --link ./ $GOPATH/pkg/mod/github.com/therealkidmagic/coredns-isonetworking

RUN go mod edit -replace isonetworking=/plugin
# RUN go mod edit -replace isonetworking=$GOPATH/pkg/mod/github.com/therealkidmagic/coredns-isonetworking

RUN sed -i "${PLUGIN_PRIO} i\\    docker:isonetworking" plugin.cfg
# RUN sed -i "s/^#.*//g; /^$/d; $PLUGIN_PRIO i docker:isonetworking" plugin.cfg 

RUN go generate coredns.go
RUN go build -mod=mod -o=/usr/local/bin/coredns
RUN strip -vs /usr/local/bin/coredns
    
FROM alpine:${ALPINE_VERS}
RUN apk --no-cache add ca-certificates gettext

# Copy the compiled CoreDNS binary from the builder stage
COPY --from=builder /usr/local/bin/coredns /usr/local/bin/coredns

# Set up the working directory and copy necessary files for runtime
WORKDIR /etc/coredns
COPY Corefile.tmpl .
COPY entrypoint.sh .

# Make the entrypoint script executable
RUN chmod +x /etc/coredns/entrypoint.sh

ENTRYPOINT ["/etc/coredns/entrypoint.sh"]
