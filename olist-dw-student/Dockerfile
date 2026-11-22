# Astro Runtime 3.1 (Airflow 3.1) - "-base" variant: it has no automatic ONBUILD steps,
# so this file controls the order of the layers:
#   slow steps that rarely change FIRST (built once, then taken from the cache),
#   project files LAST (they change often, and now only this last, fast step is redone).
FROM astrocrpublic.azurecr.io/runtime:3.1-13-base

# 1. Microsoft ODBC Driver 18 (pyodbc, dbt-sqlserver) + sqlcmd ............ cached
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg2 ca-certificates \
 && DEBIAN_MAJOR=$(grep VERSION_ID /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1) \
 && curl -sSL -o /tmp/packages-microsoft-prod.deb \
      https://packages.microsoft.com/config/debian/${DEBIAN_MAJOR}/packages-microsoft-prod.deb \
 && dpkg -i /tmp/packages-microsoft-prod.deb \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 mssql-tools18 unixodbc \
 && rm -rf /var/lib/apt/lists/* /tmp/packages-microsoft-prod.deb
ENV PATH="${PATH}:/opt/mssql-tools18/bin"
USER astro

# 2. dbt in its own virtualenv, used by Cosmos (DAG dbt_olist) ............. cached
#    [pyodbc] est OBLIGATOIRE depuis dbt-sqlserver 1.12 :
#    pyodbc n'est plus installé par défaut, or profiles.yml utilise ce backend.
RUN python -m venv dbt_venv \
 && dbt_venv/bin/pip install --no-cache-dir "dbt-sqlserver[pyodbc]>=1.10,<2.0"

# 3. Python packages for Airflow: redone only when requirements.txt changes
COPY --chown=astro:0 requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 4. Project files: the only step redone when you edit the project
COPY --chown=astro:0 . .
