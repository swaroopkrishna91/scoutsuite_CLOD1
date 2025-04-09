# 🛡️ Cloud Security Compliance Dashboard using Scout Suite + Grafana

This repository automates the setup of a cloud compliance dashboard on a **Windows machine** using Docker. It uses `scoutsuite.json` as input, parses it with a custom Python exporter, and visualizes the data in Grafana.

---

## 📌 Prerequisites

Ensure the following are installed on your Windows system:

- [Python 3.9](https://www.python.org/downloads/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)

---

## ✨ Setup Instructions

### 1. Clone the Repository

```powershell
git clone https://github.com/swaroopkrishna91/scoutsuite_CLOD1.git
cd scoutsuite_CLOD1
```

---

### 2. Add `scoutsuite.json` File

Place your `data.json` output file (from [Scout Suite](https://github.com/nccgroup/ScoutSuite)) into the **root** of the cloned repository.

> 📍 This file is required for the dashboard to populate data.

---

### 3. Run the Setup Script

Execute the provided PowerShell script to automatically:

- Create necessary directories
- Build the required Docker image
- Spin up Prometheus, Grafana, and the custom Python exporter containers

```powershell
.\setup_monitoring.ps1
```

This will take a few moments to complete.

---

## 📊 Access Grafana Dashboard

Once the setup is complete:

1. Open your browser and navigate to: [http://localhost:3000](http://localhost:3000)
2. Login using:
   - **Username:** `admin`
   - **Password:** `admin`
3. Navigate to **Dashboards → Import**
4. Upload the included `grafana_template.json` or use dashboard ID (if applicable)
5. Select the correct Prometheus data source and click **Import**

---

## 🛍 Folder Structure

```
scoutsuite_CLOD1/
│
├── scoutsuite.json         # Required input file
├── setup.ps1               # PowerShell automation script
├── Dockerfile              # Python exporter Docker build
├── docker-compose.yml      # Docker stack definition
├── prometheus.yml          # Prometheus configuration
└── README.md               # This file
```

---

## 🐳 Docker Services

| Container       | Purpose                            | Port         |
|----------------|------------------------------------|--------------|
| Grafana         | Dashboard UI                       | `3000`       |
| Prometheus      | Metrics collection                 | `9090`       |
| Python Exporter | Parses ScoutSuite output           | *(internal)* |
| Pushgateway     | Metric buffering (optional)        | `9091`       |

---

## 🪩 Tear Down

To stop all running containers:

```powershell
docker-compose down
```

To remove all unused Docker data:

```powershell
docker system prune -a --volumes
```

---