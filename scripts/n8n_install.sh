# Crear un volumen dedicado
docker volume create n8n_data

# Ejecutar el contenedor usando el volumen (sin montar una carpeta local)
docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p 5678:5678 \
  -v n8n_data:/home/node/.n8n \
  n8nio/n8n

sudo chown -R 1000:1000 ~/.n8n


docker rm -f n8n   # si existe
docker run -d --name n8n --restart unless-stopped -p 5678:5678 -v ~/.n8n:/home/node/.n8n n8nio/n8n


docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p 5678:5678 \
  --user "$(id -u):$(id -g)" \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
