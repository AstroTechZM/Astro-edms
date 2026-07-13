# syntax=docker/dockerfile:1

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libffi-dev \
        libjpeg-dev \
        libldap2-dev \
        libpng-dev \
        libsasl2-dev \
        libssl-dev \
        libtiff-dev \
        libpq-dev \
        zlib1g-dev \
        libcairo2-dev \
        libpango1.0-dev \
        libgdk-pixbuf2.0-dev \
        libmagic1 \
        gettext \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements/production.txt ./requirements/production.txt
RUN pip install --upgrade pip setuptools wheel \
    && pip install -r requirements/production.txt

COPY . .

EXPOSE 8000

CMD ["gunicorn", "mayan.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2"]
