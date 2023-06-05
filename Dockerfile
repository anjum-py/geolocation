FROM ubuntu as maxmind-db
RUN apt update
RUN apt install -y software-properties-common
RUN apt update
RUN add-apt-repository ppa:maxmind/ppa
RUN apt install -y geoipupdate
WORKDIR /workspace
COPY .env .env
RUN set -a; \
    [ -f .env ] && . ./.env; \
    set +a; \
    conf_file=/etc/GeoIP.conf \
    && echo "Creating GeoIP configuration file - $conf_file" \
    && echo "AccountID $GEOIPUPDATE_ACCOUNT_ID" > "$conf_file" \
    && echo "LicenseKey $GEOIPUPDATE_LICENSE_KEY" >> "$conf_file" \
    && echo "EditionIDs $GEOIPUPDATE_EDITION_IDS" >> "$conf_file" \
    && echo "DatabaseDirectory $GEOIPUPDATE_DB_DIR" >> "$conf_file";
RUN geoipupdate -v

FROM python:slim-buster AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    libmaxminddb-dev \
    libmaxminddb0 \
    python3-dev; \
    rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade --no-cache-dir pip
RUN pip install --no-cache-dir -U poetry
WORKDIR /app
COPY poetry.lock pyproject.toml ./
RUN mkdir -p src
COPY src/ ./src
COPY prod_server.py ./prod_server.py
COPY parse_env.py ./parse_env.py
COPY .env ./.env

RUN poetry config virtualenvs.in-project true \
    && poetry install --no-root --no-interaction --no-ansi --without dev,test;

FROM python:slim-buster as final

RUN set -a; \
    [ -f .env ] && . ./.env; \
    set +a;

RUN apt-get update && apt-get install -y --no-install-recommends libmaxminddb0 \
    && rm -rf /var/lib/apt/lists/*;

WORKDIR /app
RUN mkdir -p db
COPY --from=builder /app .
COPY --from=maxmind-db /workspace/db db

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8080

CMD ["python", "prod_server.py"]
