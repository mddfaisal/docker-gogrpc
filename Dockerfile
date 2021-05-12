FROM alpine:3.13

RUN apk add \
	build-base \
	curl \
	automake \
	autoconf \
	libtool \
	git \
	zlib-dev \
	bash \
	gcc \
	gnupg \
	musl-dev \
	go \
	openssl

ENV GOLANG_VERSION=1.16.4 \
	GOARCH=amd64 \
	GOOS=linux \
	URL=https://dl.google.com/go/go1.16.4.src.tar.gz \
	PATH=/usr/local/go/bin:$PATH \
	OUTDIR=/out

RUN cd /tmp && wget -O go.tgz ${URL} && \
	tar -C /usr/local -xzf go.tgz && \
	rm -rf go.tgz

RUN cd /usr/local/go/src && \
	export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH" && \
	./make.bash && go install std

RUN rm -rf /usr/local/go/pkg/*/cmd \
	/usr/local/go/pkg/bootstrap \
	/usr/local/go/pkg/obj \
	/usr/local/go/pkg/tool/*/api \
	/usr/local/go/pkg/tool/*/go_bootstrap \
	/usr/local/go/src/cmd/dist/dist

ENV GOPATH=/go
ENV PATH=$GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"


RUN mkdir -p /protobuf && curl -L https://github.com/google/protobuf/archive/v3.6.1.tar.gz | tar xvz --strip-components=1 -C /protobuf
RUN git clone --depth 1 --recursive -b v1.16.0 https://github.com/grpc/grpc.git /grpc && \
	rm -rf grpc/third_party/protobuf

RUN ln -s /protobuf /grpc/third_party/protobuf
RUN cd /protobuf && autoreconf -f -i -Wall,no-obsolete && \
	./configure --prefix=/usr --enable-static=no && \
	make -j2 && \
	make install

RUN cd /grpc && make -j2 plugins
RUN cd /protobuf && make install DESTDIR=${OUTDIR}
RUN cd /grpc && make install-plugins prefix=${OUTDIR}/usr

RUN go get -u -v -ldflags '-w -s' \
        google.golang.org/protobuf/cmd/protoc-gen-go \
        google.golang.org/grpc/cmd/protoc-gen-go-grpc

RUN apk del \
	build-base \
	curl \
	automake \
	autoconf \
	libtool \
	git \
	zlib-dev \
	bash \
	gcc \
	gnupg \
	musl-dev \
	openssl


