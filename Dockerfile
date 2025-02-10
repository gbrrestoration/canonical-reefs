FROM julia:1.11.3-bookworm AS julia

WORKDIR /app
COPY . /app

RUN apt-get update
RUN apt-get install -y coreutils

#instantiate julia project environment 
RUN julia --project=. -e 'using Pkg; Pkg.instantiate();'

RUN mkdir -p /opt/data/bathy
RUN echo "[bathy]\nBATHY_DATA_DIR = '/opt/data/bathy'\n" > .config.toml


ENTRYPOINT ["./entrypoint.sh"]
CMD ["ls"]

