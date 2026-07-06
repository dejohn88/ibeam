FROM python:3.11-slim-bookworm

ENV PATH="/opt/venv/bin:$PATH" \
    JAVA_HOME="/usr/lib/jvm/default-java" \
    USER_ID="1000" \
    GROUP_ID="1000" \
    USER_NAME="basic_user" \
    GROUP_NAME="basic_group" \
    SRC_ROOT="/srv/ibeam" \
    OUTPUTS_DIR="/srv/outputs" \
    IBEAM_GATEWAY_DIR="/srv/clientportal.gw" \
    IBEAM_CHROME_DRIVER_PATH="/usr/bin/chromedriver" \
    PYTHONPATH="${PYTHONPATH}:/srv:/srv/ibeam"

COPY requirements.txt /srv/requirements.txt

RUN \
    # Create python virtual environment and required directories
    python -m venv /opt/venv && \
    mkdir -p /usr/share/man/man1 $OUTPUTS_DIR $IBEAM_GATEWAY_DIR $SRC_ROOT && \
    # Create basic user
    addgroup --gid $GROUP_ID $GROUP_NAME && \
    adduser --disabled-password --gecos "" --uid $USER_ID --gid $GROUP_ID --shell /bin/bash $USER_NAME && \
    # Install apt packages (chromium/chromium-driver replaced by a pinned
    # Chrome for Testing build below - the unpinned Debian package pulls
    # whatever is newest at build time, which broke Chrome startup in this
    # container after a routine rebuild)
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre dbus-x11 xfonts-base xfonts-100dpi \
        xfonts-75dpi xfonts-scalable xorg xvfb gtk2-engines-pixbuf nano curl iputils-ping unzip \
        ca-certificates fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 \
        libcups2 libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 libnspr4 libnss3 libx11-6 libxcomposite1 \
        libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 xdg-utils \
        build-essential && \
    # Install a pinned Chrome for Testing build (v144.0.7559.133) instead of
    # the rolling Debian chromium package
    curl -fsSL -o /tmp/chrome.zip https://storage.googleapis.com/chrome-for-testing-public/144.0.7559.133/linux64/chrome-linux64.zip && \
    curl -fsSL -o /tmp/chromedriver.zip https://storage.googleapis.com/chrome-for-testing-public/144.0.7559.133/linux64/chromedriver-linux64.zip && \
    unzip -q /tmp/chrome.zip -d /opt && \
    unzip -q /tmp/chromedriver.zip -d /opt && \
    mv /opt/chrome-linux64 /opt/chrome-for-testing && \
    mv /opt/chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    chmod +x /usr/bin/chromedriver /opt/chrome-for-testing/chrome && \
    rm -rf /tmp/chrome.zip /tmp/chromedriver.zip /opt/chromedriver-linux64 && \
    # Download the Client Portal Gateway fresh instead of using the vendored
    # copy_cache/clientportal.gw (checked in ~April 2023 and never refreshed).
    # That stale JAR can complete SSO login but fails to establish the
    # "iserver bridge" to IBKR's backend, leaving auth/status stuck at
    # authenticated:false indefinitely - a known issue (Voyz/ibeam #279)
    # fixed by pulling a current build from IBKR's own always-current URL.
    curl -fsSL -o /tmp/cpgw.zip https://download2.interactivebrokers.com/portal/clientportal.gw.zip && \
    unzip -q /tmp/cpgw.zip -d $IBEAM_GATEWAY_DIR && \
    rm -f /tmp/cpgw.zip && \
    # Install python packages
    pip install --upgrade pip setuptools wheel && \
    pip install -r /srv/requirements.txt && \
    # Remove packages and package lists
    apt-get purge -y --auto-remove build-essential && \
    rm -rf /var/lib/apt/lists/*

COPY ibeam $SRC_ROOT
COPY nginx.conf /srv/ibeam/nginx.conf
COPY start.sh /srv/ibeam/start.sh
COPY proxy.py /srv/ibeam/proxy.py

RUN \
    # Create environment activation script
    echo "/opt/venv/bin/activate" >> $SRC_ROOT/activate.sh && \
    # Update file ownership and permissions
    chown -R $USER_NAME:$GROUP_NAME $SRC_ROOT $OUTPUTS_DIR $IBEAM_GATEWAY_DIR && \
    chmod 744 /opt/venv/bin/activate /srv/ibeam/run.sh $SRC_ROOT/activate.sh /srv/ibeam/start.sh

WORKDIR $SRC_ROOT

USER $USER_NAME

CMD ["/srv/ibeam/start.sh"]
