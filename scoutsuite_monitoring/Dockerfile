FROM python:3.9
WORKDIR /app
COPY json_exporter.py /app
COPY data.json /data/data.json
RUN pip install flask prometheus_client requests
CMD ["python", "json_exporter.py"]
