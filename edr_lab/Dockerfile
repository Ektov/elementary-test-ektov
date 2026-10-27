FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Pin to the same CLI major used by this sandbox (dbt package ~0.25.x).
RUN pip install --no-cache-dir 'elementary-data[postgres]==0.25.1'

WORKDIR /work
ENTRYPOINT ["edr"]
CMD ["report", "--profiles-dir", "/config", "--profile-target", "lab", "--file-path", "/out/elementary_report.html"]
