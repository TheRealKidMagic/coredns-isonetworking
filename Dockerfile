# Dockerfile
FROM golang:1.20-alpine AS builder

ENV COREDNS_VERSION=1.10.1
ENV COREDNS_PLUGINS="file:./plugin/file,forward:./plugin/forward,iprewrite:./plugin/iprewrite"

# Install Git and make
RUN apk add --no-cache git make

# Clone CoreDNS source
RUN git clone https://github.com/coredns/coredns.git /go/src/github.com/coredns/coredns
WORKDIR /go/src/github.com/coredns/coredns

# Copy the iprewrite plugin source code into the CoreDNS source directory
COPY ./plugin/iprewrite ./plugin/iprewrite/

# Add iprewrite plugin to the plugin.cfg file
RUN echo "iprewrite:./plugin/iprewrite" >> plugin.cfg

# Build CoreDNS with iprewrite plugin
RUN make coredns

# Final Image
FROM alpine:3.18
RUN apk add --no-cache gettext

COPY --from=builder /go/src/github.com/coredns/coredns/coredns /usr/local/bin/coredns

WORKDIR /etc/coredns
COPY Corefile.tmpl .
COPY entrypoint.sh .

RUN chmod +x /etc/coredns/entrypoint.sh

ENTRYPOINT ["/etc/coredns/entrypoint.sh"]
