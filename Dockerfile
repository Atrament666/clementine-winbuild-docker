from i386/ubuntu:xenial

run echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections

run apt-get update && apt-get install -y \
    yasm cmake qt4-dev-tools stow unzip autoconf libtool \
    bison flex pkg-config gettext libglib2.0-dev intltool wine git-core \
    sudo texinfo wget nsis \
    protobuf-compiler


# Install the old version of libtool
run wget -q -O /libtool.deb 'https://storage.googleapis.com/clementine-data.appspot.com/Build%20dependencies/libtool_2.2.6b-2ubuntu1_i386.deb' && \
    dpkg -i /libtool.deb && \
    rm /libtool.deb

# Install the mingw toolchain and add it to the path
run wget --progress=dot:mega -O /mingw.tar.bz2 \
     'https://storage.googleapis.com/clementine-data.appspot.com/Build%20dependencies/mingw-w32-bin_i686-linux_20130523.tar.bz2' && \
    mkdir /mingw && \
    tar -xvf /mingw.tar.bz2 -C /mingw && \
    rm /mingw.tar.bz2 && \
    ln -v -s /mingw/bin/* /bin/ && \
    find /mingw -executable -exec chmod go+rx {} ';' && \
    find /mingw -readable -exec chmod go+r {} ';'

# Work around https://github.com/docker/docker/issues/6047
run rm -rf /root && mkdir /root --mode 0755

#build dependencies
run mkdir /usr/i586-mingw32msvc && \
    ln -s /usr/i586-mingw32msvc /target && \
    mkdir /src /target/stow /target/bin && \
    ln -s /mingw/i686-w64-mingw32/lib/libgcc_s_sjlj-1.dll /target/bin/ && \
    git clone https://github.com/Atrament666/Dependencies.git /src

workdir /src/windows
run make

#setup wine
run sed -i '22700s/.*/"PATH"=str(2):"C:\\\\windows\\\\system32;C:\\\\windows;C:\\\\windows\\\\system32\\\\wbem;Z:\\\\src\\\\windows\\\\clementine-deps\\\\"/' ~/.wine/system.reg


#build clementine 

workdir /src
run git clone --depth=1 https://github.com/Atrament666/Clementine.git clementine 
workdir /src/clementine/bin
run PKG_CONFIG_LIBDIR=/target/lib/pkgconfig \
    cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=/src/Toolchain-mingw32.cmake \
    -DQT_HEADERS_DIR=/target/include \
    -DQT_LIBRARY_DIR=/target/bin \
    -DPROTOBUF_PROTOC_EXECUTABLE=/target/bin/protoc.exe \
		-DGLEW_LIBRARIES=/target/stow/glew-1.5.5/bin/glew32.dll

run make 

workdir /src/clementine/dist/windows
run ln -s /src/windows/clementine-deps/* . && \
    ln -s ../../bin/clementine*.exe . && \
    makensis clementine.nsi && \
		mkdir /output && \
		cp ClementineSetup-1.3.1.exe /output
volume /output
