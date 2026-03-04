# Utilisation d'une base Debian (plus stable pour OpenSlide que Alpine)
FROM python:3.10-slim-bullseye

# 1. Installation des dépendances système (OpenSlide, GL, et compilateurs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libopenslide0 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 2. Installation des dépendances Python
# On installe d'abord les gros morceaux pour profiter du cache Docker
RUN pip install --no-cache-dir \
    torch \
    torchvision \
    --index-url https://download.pytorch.org/whl/cpu 

# Note: Remplacez par la version GPU si vous avez un GPU Linux, 
# mais pour le patching sur Mac, le CPU est suffisant.

COPY requirements_docker.txt .
RUN pip install --no-cache-dir -r requirements_docker.txt

# 3. Installation spécifique (Smooth-TopK)
RUN pip install git+https://github.com/oval-group/smooth-topk.git

# Copie du code source
COPY . .

CMD ["bash"]