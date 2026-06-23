# syntax=docker/dockerfile:1
# Copyright ⓒ 2024-2026 Peter Morgan <peter.james.morgan@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx

FROM --platform=$BUILDPLATFORM rust:1.88-alpine AS builder
COPY --from=xx / /
RUN apk add clang cmake lld

ARG TARGETPLATFORM
ENV CARGO_BUILD_JOBS=4
RUN xx-apk add --no-cache musl-dev zlib-dev zlib-static gcc

WORKDIR /usr/src
# Install the toolchain pinned by rust-toolchain.toml in a cached layer that is
# only invalidated when rust-toolchain.toml changes (not on every source edit).
COPY rust-toolchain.toml .
RUN rustup show && rustup target add $(xx-cargo --print-target-triple)

ADD / /usr/src/

# The target dir is a cache mount, so it only exists during this RUN. Copy the
# built binary out to a real layer path (/usr/src/tansu) before the mount goes away.
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/usr/src/build \
    xx-cargo build --bin tansu --no-default-features --features dynostore --release --target-dir ./build \
    && cp ./build/$(xx-cargo --print-target-triple)/release/tansu /tansu
RUN xx-verify --static /tansu

RUN <<EOF
mkdir -p /image/schema /image/data /image/tmp /image/etc/ssl
cp -v /tansu /image/tansu
cp -v LICENSE /image
cp -rv /etc/ssl /image/etc
EOF

FROM scratch
COPY --from=builder /image /
ENV TMP=/tmp
ENTRYPOINT ["/tansu"]
CMD ["broker"]
