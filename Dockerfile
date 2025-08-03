# Dockerfile
# Start with a builder stage to compile the application
ARG GOLANG_VERS=1.20
ARG ALPINE_VERS=3.17

FROM golang:${GOLANG_VERS}-alpine${ALPINE_VERS} as builder

ARG CGO_ENABLED=1
ARG PLUGIN_PRIO=50
ARG COREDNS_VERS=1.10.1

RUN go mod download github.com/coredns/coredns@v${COREDNS_VERS}
WORKDIR $GOPATH/pkg/mod/github.com/coredns/coredns@v${COREDNS_VERS}
RUN go mod download

COPY --link ./ $GOPATH/pkg/mod/github.com/therealkidmagic/coredns-isonetworking
RUN sed -i "s/^#.*//g; /^$/d; $PLUGIN_PRIO i docker:isonetworking" plugin.cfg 
RUN go mod edit -replace isonetworking=$GOPATH/pkg/mod/github.com/therealkidmagic/coredns-isonetworking
RUN go generate coredns.go && go build -mod=mod -o=/usr/local/bin/coredns
RUN apk --no-cache add binutils && strip -vs /usr/local/bin/coredns
    
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
