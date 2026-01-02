terraform {
  required_version = ">= 1.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
  }
}

provider "null" {}

resource "null_resource" "bootstrap_docker" {
  connection {
    type = "ssh"
    host = replace(var.docker_host, "ssh://michael@", "") # Extract IP from docker_host string
    user = "michael"
    # Agent is used automatically
  }

  provisioner "remote-exec" {
    inline = [
      # Basic deps
      # "sudo apt-get update -y",
      # "sudo apt-get install -y ca-certificates curl gnupg lsb-release",

      # Install Docker Engine + compose plugin (official repo)
      # "sudo install -m 0755 -d /etc/apt/keyrings",
      # "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
      # "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      # "sudo bash -lc 'source /etc/os-release; cat > /etc/apt/sources.list.d/docker.sources <<EOF\nTypes: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: $${UBUNTU_CODENAME:-$VERSION_CODENAME}\nComponents: stable\nSigned-By: /etc/apt/keyrings/docker.asc\nEOF'",
      # "sudo apt-get update -y",
      # "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",

      # Enable docker at boot
      # "sudo systemctl enable --now docker",

      # Ensure current user is in docker group (requires relogin, but good for future)
      # "sudo usermod -aG docker $USER || true",

      # Create stack dirs
      "sudo mkdir -p /opt/portainer /opt/ollama /opt/n8n /opt/text-generation-webui /opt/librechat /opt/comfyui /opt/stable-diffusion-webui /opt/whisper-server /opt/whisperx /opt/piper-tts /opt/qdrant /opt/milvus /opt/langgraph-studio /opt/crewai",
      "sudo chown -R 1000:1000 /opt/portainer /opt/ollama /opt/n8n /opt/text-generation-webui /opt/librechat /opt/comfyui /opt/stable-diffusion-webui /opt/whisper-server /opt/whisperx /opt/piper-tts /opt/qdrant /opt/milvus /opt/langgraph-studio /opt/crewai || true",
    ]
  }
}

# Deploy Stacks
resource "null_resource" "deploy_stacks" {
  depends_on = [null_resource.bootstrap_docker]

  provisioner "local-exec" {
    command = <<EOT
      # Define HOST and USER
      HOST="${replace(var.docker_host, "ssh://michael@", "")}"
      USER="michael"

      # Copy Compose Files via SCP (renaming on destination to avoid collisions)
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/portainer/docker-compose.yml" "$USER@$HOST:/tmp/portainer.docker-compose.yml"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/ollama/docker-compose.yml" "$USER@$HOST:/tmp/ollama.docker-compose.yml"
      ${var.enable_n8n ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/n8n/docker-compose.yml\" \"$USER@$HOST:/tmp/n8n.docker-compose.yml\"" : ""}
      ${var.enable_text_generation_webui ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/text-generation-webui/docker-compose.yml\" \"$USER@$HOST:/tmp/text-generation-webui.docker-compose.yml\"" : ""}
      ${var.enable_librechat ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/librechat/docker-compose.yml\" \"$USER@$HOST:/tmp/librechat.docker-compose.yml\"" : ""}
      ${var.enable_comfyui ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/comfyui/docker-compose.yml\" \"$USER@$HOST:/tmp/comfyui.docker-compose.yml\"" : ""}
      ${var.enable_stable_diffusion_webui ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/stable-diffusion-webui/docker-compose.yml\" \"$USER@$HOST:/tmp/stable-diffusion-webui.docker-compose.yml\"" : ""}
      ${var.enable_whisper_server ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/whisper-server/docker-compose.yml\" \"$USER@$HOST:/tmp/whisper-server.docker-compose.yml\"" : ""}
      ${var.enable_whisperx ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/whisperx/docker-compose.yml\" \"$USER@$HOST:/tmp/whisperx.docker-compose.yml\"" : ""}
      ${var.enable_piper_tts ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/piper-tts/docker-compose.yml\" \"$USER@$HOST:/tmp/piper-tts.docker-compose.yml\"" : ""}
      ${var.enable_qdrant ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/qdrant/docker-compose.yml\" \"$USER@$HOST:/tmp/qdrant.docker-compose.yml\"" : ""}
      ${var.enable_milvus ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/milvus/docker-compose.yml\" \"$USER@$HOST:/tmp/milvus.docker-compose.yml\"" : ""}
      ${var.enable_langgraph_studio ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/langgraph-studio/docker-compose.yml\" \"$USER@$HOST:/tmp/langgraph-studio.docker-compose.yml\"" : ""}
      ${var.enable_crewai ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/crewai/docker-compose.yml\" \"$USER@$HOST:/tmp/crewai.docker-compose.yml\"" : ""}

      # Execute Remote Setup via SSH
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$USER@$HOST" 'bash -s' <<'REMOTE_SCRIPT'
        set -e

        # Helper for retrying commands (fixes transient DNS/network issues)
        function retry {
          local retries=5
          local count=0
          until "$@"; do
            exit=$?
            wait=$((2 ** count))
            count=$((count + 1))
            if [ $count -lt $retries ]; then
              echo "Retry $count/$retries exited $exit, retrying in $wait seconds..."
              sleep $wait
            else
              echo "Retry $count/$retries exited $exit, no more retries left."
              return $exit
            fi
          done
          return 0
        }

        # Wait for a container to enter a running (or paused) state
        function wait_for_container_ready {
          local name=$1
          local timeout=300
          local interval=5
          local waited=0

          echo "Waiting for container $name to be running..."
          while [ $waited -lt $timeout ]; do
            status=$(sudo docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo "missing")

            if [ "$status" = "running" ] || [ "$status" = "paused" ]; then
              echo "$name is running (status: $status)"
              return 0
            fi

            if [ "$status" = "exited" ] || [ "$status" = "dead" ]; then
              echo "$name reached status $status before becoming ready"
              return 1
            fi

            sleep $interval
            waited=$((waited + interval))
          done

          echo "Timed out waiting for $name to be running"
          return 1
        }

        # Restart DNS resolver to fix "server misbehaving" errors
        sudo systemctl restart systemd-resolved || true

        # Ensure directories exist (in case bootstrap didn't run or new ones matched)
        sudo mkdir -p /opt/portainer /opt/ollama /opt/n8n /opt/text-generation-webui /opt/librechat /opt/comfyui /opt/stable-diffusion-webui /opt/whisper-server /opt/whisperx /opt/piper-tts /opt/qdrant /opt/milvus /opt/langgraph-studio /opt/crewai
        sudo chown -R 1000:1000 /opt/portainer /opt/ollama /opt/n8n /opt/text-generation-webui /opt/librechat /opt/comfyui /opt/stable-diffusion-webui /opt/whisper-server /opt/whisperx /opt/piper-tts /opt/qdrant /opt/milvus /opt/langgraph-studio /opt/crewai || true

        # Configure Firewall (UFW)
        echo "Configuring Firewall..."
        sudo ufw allow 22/tcp  # SSH
        sudo ufw allow 80/tcp  # HTTP (reverse proxies / direct web access)
        sudo ufw allow 443/tcp # HTTPS (reverse proxies / direct web access)
        sudo ufw allow 8000/tcp # Portainer
        sudo ufw allow 9000/tcp # Portainer
        sudo ufw allow 3000/tcp # Open WebUI / dashboards
        sudo ufw allow 11434/tcp # Ollama
        ${var.enable_n8n ? "sudo ufw allow 5678/tcp" : ""}
        ${var.enable_text_generation_webui ? "sudo ufw allow 7860/tcp" : ""}
        ${var.enable_librechat ? "sudo ufw allow 3080/tcp\n        sudo ufw allow 7700/tcp\n        sudo ufw allow 6379/tcp\n        sudo ufw allow 27017/tcp" : ""}
        ${var.enable_comfyui ? "sudo ufw allow 8188/tcp" : ""}
        ${var.enable_stable_diffusion_webui ? "sudo ufw allow 7861/tcp" : ""}
        ${var.enable_whisper_server ? "sudo ufw allow 10300/tcp" : ""}
        ${var.enable_piper_tts ? "sudo ufw allow 10200/tcp" : ""}
        ${var.enable_qdrant ? "sudo ufw allow 6333/tcp\n        sudo ufw allow 6334/tcp" : ""}
        ${var.enable_milvus ? "sudo ufw allow 19530/tcp\n        sudo ufw allow 9091/tcp" : ""}
        ${var.enable_langgraph_studio ? "sudo ufw allow 8123/tcp" : ""}
        ${var.enable_crewai ? "sudo ufw allow 8001/tcp" : ""}
        ${var.enable_whisperx ? "sudo ufw allow 9001/tcp" : ""}
        sudo ufw --force enable || true

        # Move files to correct locations
        sudo mv /tmp/portainer.docker-compose.yml /opt/portainer/docker-compose.yml

        # Track which containers should be paused after they finish starting
        containers_to_pause=()
        ${var.enable_ollama ? "containers_to_pause+=(\"ollama\" \"open-webui\")" : ""}
        ${var.enable_n8n ? "containers_to_pause+=(\"n8n\")" : ""}
        ${var.enable_text_generation_webui ? "containers_to_pause+=(\"text-generation-webui\")" : ""}
        ${var.enable_librechat ? "containers_to_pause+=(\"librechat\" \"librechat-mongo\" \"librechat-redis\" \"librechat-meilisearch\")" : ""}
        ${var.enable_comfyui ? "containers_to_pause+=(\"comfyui\")" : ""}
        ${var.enable_stable_diffusion_webui ? "containers_to_pause+=(\"stable-diffusion-webui\")" : ""}
        ${var.enable_whisper_server ? "containers_to_pause+=(\"whisper-server\")" : ""}
        ${var.enable_whisperx ? "containers_to_pause+=(\"whisperx\")" : ""}
        ${var.enable_piper_tts ? "containers_to_pause+=(\"piper-tts\")" : ""}
        ${var.enable_qdrant ? "containers_to_pause+=(\"qdrant\")" : ""}
        ${var.enable_milvus ? "containers_to_pause+=(\"milvus\")" : ""}
        ${var.enable_langgraph_studio ? "containers_to_pause+=(\"langgraph-studio\")" : ""}
        ${var.enable_crewai ? "containers_to_pause+=(\"crewai-orchestrator\")" : ""}
        
        # Configure Ollama with GPU support if NVIDIA GPU is present
        if command -v nvidia-smi &> /dev/null; then
          echo "NVIDIA GPU detected. Enabling GPU support for Ollama..."
          cat <<EOF | sudo tee /opt/ollama/docker-compose.yml > /dev/null
version: '3.8'

services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

volumes:
  ollama_data:
EOF
          # Clean up the temp CPU File
          sudo rm -f /tmp/ollama.docker-compose.yml
        else
          echo "No NVIDIA GPU detected. Using CPU mode for Ollama."
          sudo mv /tmp/ollama.docker-compose.yml /opt/ollama/docker-compose.yml
        fi

        ${var.enable_n8n ? "sudo mv /tmp/n8n.docker-compose.yml /opt/n8n/docker-compose.yml" : ""}
        ${var.enable_text_generation_webui ? "sudo mv /tmp/text-generation-webui.docker-compose.yml /opt/text-generation-webui/docker-compose.yml" : ""}
        ${var.enable_librechat ? "sudo mv /tmp/librechat.docker-compose.yml /opt/librechat/docker-compose.yml" : ""}
        ${var.enable_comfyui ? "sudo mv /tmp/comfyui.docker-compose.yml /opt/comfyui/docker-compose.yml" : ""}
        ${var.enable_stable_diffusion_webui ? "sudo mv /tmp/stable-diffusion-webui.docker-compose.yml /opt/stable-diffusion-webui/docker-compose.yml" : ""}
        ${var.enable_whisper_server ? "sudo mv /tmp/whisper-server.docker-compose.yml /opt/whisper-server/docker-compose.yml" : ""}
        ${var.enable_whisperx ? "sudo mv /tmp/whisperx.docker-compose.yml /opt/whisperx/docker-compose.yml" : ""}
        ${var.enable_piper_tts ? "sudo mv /tmp/piper-tts.docker-compose.yml /opt/piper-tts/docker-compose.yml" : ""}
        ${var.enable_qdrant ? "sudo mv /tmp/qdrant.docker-compose.yml /opt/qdrant/docker-compose.yml" : ""}
        ${var.enable_milvus ? "sudo mv /tmp/milvus.docker-compose.yml /opt/milvus/docker-compose.yml" : ""}
        ${var.enable_langgraph_studio ? "sudo mv /tmp/langgraph-studio.docker-compose.yml /opt/langgraph-studio/docker-compose.yml" : ""}
        ${var.enable_crewai ? "sudo mv /tmp/crewai.docker-compose.yml /opt/crewai/docker-compose.yml" : ""}

        # Deploy Stacks
        ${var.enable_portainer ? "cd /opt/portainer && (sudo docker rm -f portainer || true) && retry sudo docker compose up -d" : "echo 'Skipping Portainer'"}
        ${var.enable_ollama ? "cd /opt/ollama && (sudo docker rm -f ollama || true) && retry sudo docker compose up -d && sleep 10 && retry sudo docker exec ollama ollama pull tinyllama && retry sudo docker exec ollama ollama pull starcoder:1b && retry sudo docker exec ollama ollama pull gpt-oss" : "echo 'Skipping Ollama'"}
        ${var.enable_n8n ? "cd /opt/n8n && (sudo docker rm -f n8n || true) && retry sudo docker compose up -d n8n" : "echo 'Skipping n8n'"}
        ${var.enable_text_generation_webui ? "cd /opt/text-generation-webui && (sudo docker rm -f text-generation-webui || true) && retry sudo docker compose up -d text-generation-webui" : "echo 'Skipping Text Generation WebUI'"}
        ${var.enable_librechat ? "cd /opt/librechat && (sudo docker rm -f librechat librechat-mongo librechat-redis librechat-meilisearch || true) && retry sudo docker compose up -d" : "echo 'Skipping LibreChat'"}
        ${var.enable_comfyui ? "cd /opt/comfyui && (sudo docker rm -f comfyui || true) && retry sudo docker compose up -d comfyui" : "echo 'Skipping ComfyUI'"}
        ${var.enable_stable_diffusion_webui ? "cd /opt/stable-diffusion-webui && (sudo docker rm -f stable-diffusion-webui || true) && retry sudo docker compose up -d stable-diffusion-webui" : "echo 'Skipping Stable Diffusion WebUI'"}
        ${var.enable_whisper_server ? "cd /opt/whisper-server && (sudo docker rm -f whisper-server || true) && retry sudo docker compose up -d whisper-server" : "echo 'Skipping Whisper server'"}
        ${var.enable_whisperx ? "cd /opt/whisperx && (sudo docker rm -f whisperx || true) && retry sudo docker compose up -d whisperx" : "echo 'Skipping WhisperX'"}
        ${var.enable_piper_tts ? "cd /opt/piper-tts && (sudo docker rm -f piper-tts || true) && retry sudo docker compose up -d piper-tts" : "echo 'Skipping Piper TTS'"}
        ${var.enable_qdrant ? "cd /opt/qdrant && (sudo docker rm -f qdrant || true) && retry sudo docker compose up -d qdrant" : "echo 'Skipping Qdrant'"}
        ${var.enable_milvus ? "cd /opt/milvus && (sudo docker rm -f milvus || true) && retry sudo docker compose up -d milvus" : "echo 'Skipping Milvus'"}
        ${var.enable_langgraph_studio ? "cd /opt/langgraph-studio && (sudo docker rm -f langgraph-studio || true) && retry sudo docker compose up -d langgraph-studio" : "echo 'Skipping LangGraph Studio'"}
        ${var.enable_crewai ? "cd /opt/crewai && (sudo docker rm -f crewai-orchestrator || true) && retry sudo docker compose up -d crewai-orchestrator" : "echo 'Skipping CrewAI orchestrator'"}

        # Wait for all managed containers to finish initial startup before pausing them
        if [ ${#containers_to_pause[@]} -gt 0 ]; then
          for container in "${containers_to_pause[@]}"; do
            wait_for_container_ready "$container"
          done

          for container in "${containers_to_pause[@]}"; do
            if [ "$container" != "portainer" ]; then
              echo "Pausing $container to reduce resource usage while keeping Portainer active..."
              sudo docker pause "$container" || true
            fi
          done
        fi
REMOTE_SCRIPT
    EOT
  }
}
