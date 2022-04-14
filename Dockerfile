FROM nvidia/cuda:11.2.0-devel-ubuntu20.04 as builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
	build-essential autoconf automake libtool \
	libssl-dev pkg-config gcc g++ make nasm \
	libmp3lame-dev libopus-dev libopusfile-dev libvorbis-dev libogg-dev \
	&& apt-get clean 

WORKDIR /src

ADD ./git /src/git

RUN mkdir -p /src/x264/obj && cd /src/x264/obj \
  && ../../git/x264/configure \
          --prefix=/usr/local/ffmpeg \
          --enable-shared \
  && make -j$(nproc) && make install

RUN cd /src/git/fdk-aac && ./autogen.sh \
	&& ./configure \
		--prefix=/usr/local/ffmpeg \
		--enable-shared \
	&& make -j$(nproc) && make install

RUN cd /src/git/nv-codec-headers && make install

RUN mkdir -p /src/ffmpeg/obj && cd /src/ffmpeg/obj && \
PKG_CONFIG_PATH=/usr/local/ffmpeg/lib/pkgconfig/ \
../../git/ffmpeg/configure \
	--disable-doc \
        --enable-shared --disable-static \
        --prefix=/usr/local/ffmpeg \
        --enable-nonfree --enable-gpl --enable-version3 \
        --enable-cuda-nvcc \
        --enable-cuvid --enable-nvenc --enable-libnpp \
        --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 \
        --progs-suffix=3 \
        --arch=x86_64 \
        \
        --enable-libfdk-aac --enable-libmp3lame --enable-libopus --enable-libvorbis --enable-libx264 \
        --enable-openssl \
	&& make -j$(nproc) && make install


FROM nvidia/cuda:11.2.0-runtime-ubuntu20.04

RUN apt-get update && apt-get install -y \
	libmp3lame0 libopus0 libopusfile0 libvorbis0a libvorbisenc2 libvorbisfile3 libogg0 \
	libnvidia-encode-470 \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/ffmpeg /usr/local/ffmpeg
RUN echo /usr/local/ffmpeg/lib > /etc/ld.so.conf.d/ffmpeg.conf && ldconfig
ENV PATH=/usr/local/ffmpeg/bin:$PATH

