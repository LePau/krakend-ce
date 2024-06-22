ARG GOLANG_VERSION
ARG ALPINE_VERSION

FROM golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} as builder

# LURA_VERSION is assumed to be in sync with Krakend version.  If that's not true, then update Makefile to pass in correct version
ARG LURA_VERSION
ENV LURA_VERSION="$LURA_VERSION"
RUN apk --no-cache --virtual .build-deps add make gcc musl-dev binutils-gold git

# manually retrieve our custom LUA code that accepts HEAD and put it where go expects it so that we don't have to do funny business with namespace switching betweeing github.com/LePau and luraproject
# 
WORKDIR /go
RUN echo $LURA_VERSION version
RUN mkdir -p {src,bin,pkg}
RUN mkdir -p /go/pkg/mod/github.com/luraproject/lura
WORKDIR /go/pkg/mod/github.com/luraproject/lura/
RUN git clone https://github.com/LePau/lura.git
RUN mv lura v2@v${LURA_VERSION}
WORKDIR /go/pkg/mod/github.com/luraproject/lura/v2@v${LURA_VERSION}
RUN pwd
RUN ls -al .
RUN cat /go/pkg/mod/github.com/luraproject/lura/v2@v${LURA_VERSION}/router/gin/router.go
RUN go get ./...

WORKDIR /go
RUN find | grep -i lura

COPY . /app
WORKDIR /app

RUN make build

# IMPORTANT: make sure the find command only returns one set of lura files, expected to be in pkg/mod
# if there is more than one, then our code above didn't put the custom lura code in the right place that go expects it
WORKDIR /go
RUN find | grep -i lura
RUN cat /go/pkg/mod/github.com/luraproject/lura/v2@v${LURA_VERSION}/router/gin/router.go

FROM alpine:${ALPINE_VERSION}

LABEL maintainer="community@krakend.io"

RUN apk upgrade --no-cache --no-interactive && apk add --no-cache ca-certificates tzdata && \
    adduser -u 1000 -S -D -H krakend && \
    mkdir /etc/krakend && \
    echo '{ "version": 3 }' > /etc/krakend/krakend.json

COPY --from=builder /app/krakend /usr/bin/krakend

USER 1000

WORKDIR /etc/krakend

ENTRYPOINT [ "/usr/bin/krakend" ]
CMD [ "run", "-c", "/etc/krakend/krakend.json" ]

EXPOSE 8000 8090
