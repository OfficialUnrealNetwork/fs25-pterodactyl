FROM toetje585/arch-fs25server:latest

USER root

# Adapt the upstream FS25 Wine/noVNC image to Pterodactyl's persistent
# /home/container volume and standard container user.
RUN set -eux; \
    if ! getent group container >/dev/null 2>&1; then groupadd -o -g 988 container; fi; \
    if ! id container >/dev/null 2>&1; then useradd -o -u 988 -g container -d /home/container -s /bin/bash container; fi; \
    mkdir -p /home/container /opt/ptero-fs25-build; \
    if [ -d /home/nobody/.build ]; then cp -a /home/nobody/.build/. /opt/ptero-fs25-build/; fi; \
    grep -RIlZ -e '/opt/fs25' -e '/home/nobody' /usr/local/bin /opt/ptero-fs25-build 2>/dev/null \
      | xargs -0 -r sed -i \
          -e 's#/opt/fs25#/home/container#g' \
          -e 's#/home/nobody#/home/container#g' \
          -e 's#users/nobody#users/container#g'; \
    chown -R container:container /home/container /opt/ptero-fs25-build

COPY --chown=root:root ptero-entrypoint.sh /usr/local/bin/ptero-entrypoint.sh
COPY --chown=root:root ptero-start.sh /usr/local/bin/ptero-start.sh
COPY --chown=root:root ptero-setup-fs25.sh /usr/local/bin/ptero-setup-fs25.sh

# Windows checkouts can convert shell scripts to CRLF. Strip carriage returns
# inside the image so Linux can execute the shebangs reliably.
RUN set -eux; \
    sed -i 's/\r$//' \
      /usr/local/bin/ptero-entrypoint.sh \
      /usr/local/bin/ptero-start.sh \
      /usr/local/bin/ptero-setup-fs25.sh; \
    test -f /usr/local/bin/setup_fs25.sh; \
    mv /usr/local/bin/setup_fs25.sh /usr/local/bin/setup_fs25-upstream.sh; \
    mv /usr/local/bin/ptero-setup-fs25.sh /usr/local/bin/setup_fs25.sh; \
    chmod 0755 \
      /usr/local/bin/ptero-entrypoint.sh \
      /usr/local/bin/ptero-start.sh \
      /usr/local/bin/setup_fs25.sh \
      /usr/local/bin/setup_fs25-upstream.sh; \
    test -x /usr/local/bin/ptero-entrypoint.sh; \
    head -n 1 /usr/local/bin/ptero-entrypoint.sh | grep -qx '#!/bin/bash'

ENV HOME=/home/container \
    USER=container \
    WINEPREFIX=/home/container/.fs25server \
    DISPLAY=:0

WORKDIR /home/container
USER container

EXPOSE 10823/tcp 10823/udp 6080/tcp 7999/tcp 5900/tcp

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/ptero-entrypoint.sh"]
