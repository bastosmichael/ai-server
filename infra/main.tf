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

locals {
  ai_extras_flags = {
    text_generation_webui  = var.enable_ai_extras || var.enable_text_generation_webui
    librechat              = var.enable_ai_extras || var.enable_librechat
    comfyui                = var.enable_ai_extras || var.enable_comfyui
    stable_diffusion_webui = var.enable_ai_extras || var.enable_stable_diffusion_webui
    whisper_server         = var.enable_ai_extras || var.enable_whisper_server
    piper_tts              = var.enable_ai_extras || var.enable_piper_tts
    qdrant                 = var.enable_ai_extras || var.enable_qdrant
    milvus                 = var.enable_ai_extras || var.enable_milvus
    langgraph_studio       = var.enable_ai_extras || var.enable_langgraph_studio
    crewai                 = var.enable_ai_extras || var.enable_crewai
    n8n                    = var.enable_ai_extras || var.enable_n8n
    whisperx               = var.enable_ai_extras || var.enable_whisperx
  }

  enable_any_ai_extras = contains(values(local.ai_extras_flags), true)
}

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
      "sudo mkdir -p /opt/portainer /opt/ollama /opt/ai-extras",
      "sudo chown -R 1000:1000 /opt/portainer /opt/ollama /opt/ai-extras || true",
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
      ${local.enable_any_ai_extras ? "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"${path.module}/stacks/ai-extras/docker-compose.yml\" \"$USER@$HOST:/tmp/ai-extras.docker-compose.yml\"" : ""}

      # Execute Remote Setup via SSH
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$USER@$HOST" 'bash -s' <<'REMOTE_SCRIPT'
        set -e

        AI_EXTRAS_ENABLED="${local.enable_any_ai_extras ? "true" : "false"}"
        
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

        # Restart DNS resolver to fix "server misbehaving" errors
        sudo systemctl restart systemd-resolved || true

        # Ensure directories exist (in case bootstrap didn't run or new ones matched)
        sudo mkdir -p /opt/portainer /opt/ollama /opt/ai-extras
        sudo chown -R 1000:1000 /opt/portainer /opt/ollama /opt/ai-extras || true

        # Configure Firewall (UFW)
        echo "Configuring Firewall..."
        sudo ufw allow 22/tcp  # SSH
        sudo ufw allow 80/tcp  # HTTP (reverse proxies / direct web access)
        sudo ufw allow 443/tcp # HTTPS (reverse proxies / direct web access)
        sudo ufw allow 8000/tcp # Portainer
        sudo ufw allow 9000/tcp # Portainer
        sudo ufw allow 3000/tcp # Open WebUI / dashboards
        sudo ufw allow 11434/tcp # Ollama
        if [ "$AI_EXTRAS_ENABLED" = "true" ]; then
          sudo ufw allow 5678/tcp  # n8n
          sudo ufw allow 7860/tcp  # text-generation-webui
          sudo ufw allow 3080/tcp  # LibreChat
          sudo ufw allow 7700/tcp  # Meilisearch
          sudo ufw allow 6379/tcp  # Redis
          sudo ufw allow 27017/tcp # MongoDB
          sudo ufw allow 8188/tcp  # ComfyUI
          sudo ufw allow 7861/tcp  # Stable Diffusion WebUI
          sudo ufw allow 10300/tcp # Whisper server (Wyoming)
          sudo ufw allow 10200/tcp # Piper TTS
          sudo ufw allow 6333/tcp  # Qdrant HTTP
          sudo ufw allow 6334/tcp  # Qdrant gRPC
          sudo ufw allow 19530/tcp # Milvus gRPC
          sudo ufw allow 9091/tcp  # Milvus HTTP
          sudo ufw allow 8123/tcp  # LangGraph Studio
          sudo ufw allow 8001/tcp  # CrewAI orchestrator
          sudo ufw allow 9001/tcp  # WhisperX API
        fi
        sudo ufw --force enable || true

        # Move files to correct locations
        sudo mv /tmp/portainer.docker-compose.yml /opt/portainer/docker-compose.yml
        
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

        if [ "$AI_EXTRAS_ENABLED" = "true" ]; then
          sudo mv /tmp/ai-extras.docker-compose.yml /opt/ai-extras/docker-compose.yml
        fi

        # Deploy Stacks
        ${var.enable_portainer ? "cd /opt/portainer && (sudo docker rm -f portainer || true) && retry sudo docker compose up -d" : "echo 'Skipping Portainer'"}
        ${var.enable_ollama ? "cd /opt/ollama && (sudo docker rm -f ollama || true) && retry sudo docker compose up -d && sleep 10 && retry sudo docker exec ollama ollama pull tinyllama && retry sudo docker exec ollama ollama pull starcoder:1b && retry sudo docker exec ollama ollama pull gpt-oss" : "echo 'Skipping Ollama'"}
        ${local.ai_extras_flags.n8n ? "cd /opt/ai-extras && retry sudo docker compose --profile n8n up -d n8n" : "echo 'Skipping n8n'"}
        ${local.ai_extras_flags.text_generation_webui ? "cd /opt/ai-extras && retry sudo docker compose --profile text-generation-webui up -d text-generation-webui" : "echo 'Skipping Text Generation WebUI'"}
        ${local.ai_extras_flags.librechat ? "cd /opt/ai-extras && retry sudo docker compose --profile librechat up -d librechat" : "echo 'Skipping LibreChat'"}
        ${local.ai_extras_flags.comfyui ? "cd /opt/ai-extras && retry sudo docker compose --profile comfyui up -d comfyui" : "echo 'Skipping ComfyUI'"}
        ${local.ai_extras_flags.stable_diffusion_webui ? "cd /opt/ai-extras && retry sudo docker compose --profile stable-diffusion-webui up -d stable-diffusion-webui" : "echo 'Skipping Stable Diffusion WebUI'"}
        ${local.ai_extras_flags.whisper_server ? "cd /opt/ai-extras && retry sudo docker compose --profile whisper-server up -d whisper-server" : "echo 'Skipping Whisper server'"}
        ${local.ai_extras_flags.whisperx ? "cd /opt/ai-extras && retry sudo docker compose --profile whisperx up -d whisperx" : "echo 'Skipping WhisperX'"}
        ${local.ai_extras_flags.piper_tts ? "cd /opt/ai-extras && retry sudo docker compose --profile piper-tts up -d piper-tts" : "echo 'Skipping Piper TTS'"}
        ${local.ai_extras_flags.qdrant ? "cd /opt/ai-extras && retry sudo docker compose --profile qdrant up -d qdrant" : "echo 'Skipping Qdrant'"}
        ${local.ai_extras_flags.milvus ? "cd /opt/ai-extras && retry sudo docker compose --profile milvus up -d milvus" : "echo 'Skipping Milvus'"}
        ${local.ai_extras_flags.langgraph_studio ? "cd /opt/ai-extras && retry sudo docker compose --profile langgraph-studio up -d langgraph-studio" : "echo 'Skipping LangGraph Studio'"}
        ${local.ai_extras_flags.crewai ? "cd /opt/ai-extras && retry sudo docker compose --profile crewai up -d crewai-orchestrator" : "echo 'Skipping CrewAI orchestrator'"}
REMOTE_SCRIPT
    EOT
  }
}
