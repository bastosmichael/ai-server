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
      "sudo mkdir -p /opt/portainer /opt/ollama /opt/rust-server /opt/ark /opt/cs2 /opt/minecraft /opt/plex",
      "sudo mkdir -p /opt/cs2/data",
      "sudo mkdir -p /opt/plex/media",
      "sudo chown -R 1000:1000 /opt/cs2/data || true",
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
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/rust/docker-compose.yml" "$USER@$HOST:/tmp/rust.docker-compose.yml"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/ark/docker-compose.yml" "$USER@$HOST:/tmp/ark.docker-compose.yml"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/cs2/docker-compose.yml" "$USER@$HOST:/tmp/cs2.docker-compose.yml"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/minecraft/docker-compose.yml" "$USER@$HOST:/tmp/minecraft.docker-compose.yml"
      scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${path.module}/stacks/plex/docker-compose.yml" "$USER@$HOST:/tmp/plex.docker-compose.yml"

      # Execute Remote Setup via SSH
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$USER@$HOST" 'bash -s' <<REMOTE_SCRIPT
        set -e
        
        # Ensure directories exist (in case bootstrap didn't run or new ones matched)
        sudo mkdir -p /opt/portainer /opt/ollama /opt/rust-server /opt/ark /opt/cs2 /opt/minecraft /opt/plex
        sudo mkdir -p /opt/cs2/data /opt/plex/media
        sudo chown -R 1000:1000 /opt/cs2/data || true

        # Move files to correct locations
        sudo mv /tmp/portainer.docker-compose.yml /opt/portainer/docker-compose.yml
        sudo mv /tmp/ollama.docker-compose.yml /opt/ollama/docker-compose.yml
        sudo mv /tmp/rust.docker-compose.yml /opt/rust-server/docker-compose.yml
        sudo mv /tmp/ark.docker-compose.yml /opt/ark/docker-compose.yml
        sudo mv /tmp/minecraft.docker-compose.yml /opt/minecraft/docker-compose.yml
        sudo mv /tmp/plex.docker-compose.yml /opt/plex/docker-compose.yml

        # Handle CS2 Template Replacement
        sudo mkdir -p /opt/cs2
        sudo sed -e "s/__CS2_GSLT__/${var.cs2_gslt}/g" /tmp/cs2.docker-compose.yml | sudo tee /opt/cs2/docker-compose.yml >/dev/null
        sudo rm -f /tmp/cs2.docker-compose.yml

        # Deploy Stacks
        ${var.enable_portainer ? "cd /opt/portainer && (sudo docker rm -f portainer || true) && sudo docker compose up -d" : "echo 'Skipping Portainer'"}
        ${var.enable_ollama ? "cd /opt/ollama && (sudo docker rm -f ollama || true) && sudo docker compose up -d && sleep 10 && sudo docker exec ollama ollama pull tinyllama && sudo docker exec ollama ollama pull starcoder:1b" : "echo 'Skipping Ollama'"}
        ${var.enable_rust ? "cd /opt/rust-server && (sudo docker rm -f rust-server || true) && sudo docker compose up -d" : "echo 'Skipping Rust'"}
        ${var.enable_ark ? "cd /opt/ark && (sudo docker rm -f ark-server ark_server || true) && sudo docker compose up -d" : "echo 'Skipping ARK'"}
        ${var.enable_cs2 ? "cd /opt/cs2 && (sudo docker rm -f cs2-server cs2_server || true) && sudo docker compose up -d" : "echo 'Skipping CS2'"}
        ${var.enable_minecraft ? "cd /opt/minecraft && (sudo docker rm -f minecraft-server || true) && sudo docker compose up -d" : "echo 'Skipping Minecraft'"}
        ${var.enable_plex ? "cd /opt/plex && (sudo docker rm -f plex || true) && sudo docker compose up -d" : "echo 'Skipping Plex'"}
REMOTE_SCRIPT
    EOT
  }
}
