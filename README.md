# AI (LLM) Local Server

This project manages a home server running AI-focused Docker stacks using Terraform, along with Portainer for host management.

## Project Structure
```
infra/            # Terraform configuration
  bootstrap.sh    # Manual bootstrap script (optional)
  main.tf         # Main Terraform logic
  variables.tf    # Variable definitions
  outputs.tf      # Deployment outputs
  stacks/         # Docker Compose files grouped by purpose
    # AI & tooling
    ollama/ portainer/
```

## Deployment

1. **Bootstrap and Deploy:**
   Run Terraform from the `infra/` directory. This will bootstrap the server (install Docker) and deploy your selected stacks.

   ```bash
   cd infra
   terraform init
   terraform apply \
     -var="docker_host=ssh://michael@192.168.86.38" \
     -var="enable_portainer=true" \
     -var="enable_text_generation_webui=true" \
     -var="enable_librechat=true" \
     -var="enable_comfyui=true" \
     -var="enable_stable_diffusion_webui=true" \
     -var="enable_whisper_server=true" \
     -var="enable_piper_tts=true" \
     -var="enable_qdrant=true" \
     -var="enable_milvus=true" \
     -var="enable_langgraph_studio=true" \
     -var="enable_crewai=true" \
     -var="enable_n8n=true" \
     -var="enable_whisperx=true"
   ```

   To deploy AI/LLM tooling, enable the specific services you want, such as
   `-var="enable_text_generation_webui=true"`, `-var="enable_librechat=true"`, `-var="enable_n8n=true"`, or `-var="enable_whisperx=true"`.

   **Note:** replace `192.168.86.38` with your actual server IP.

2. **Accessing Portainer & AI Tools:**
   * **Portainer:** `http://<server-ip>:9000`
   * **Ollama/Open WebUI:** `http://<server-ip>:3000` (if enabled)
   * **n8n automation:** `http://<server-ip>:5678`
   * **Text Generation WebUI:** `http://<server-ip>:7860`
   * **LibreChat (plus Mongo/Redis/Meilisearch backing services):** `http://<server-ip>:3080`
   * **ComfyUI:** `http://<server-ip>:8188`
   * **Stable Diffusion WebUI (LinuxServer):** `http://<server-ip>:7861`
   * **Whisper.cpp server:** `http://<server-ip>:9000`
   * **WhisperX API:** `http://<server-ip>:9001`
   * **Piper TTS (Wyoming):** `http://<server-ip>:10200`
   * **Qdrant:** `http://<server-ip>:6333`
   * **Milvus standalone:** `http://<server-ip>:9091`
   * **LangGraph Studio:** `http://<server-ip>:8123`
   * **CrewAI orchestrator:** `http://<server-ip>:8001`

   Terraform's remote bootstrap automatically opens UFW for HTTP/HTTPS (80/443), Open WebUI (3000), and the ports associated with any services you enable so they bind to `0.0.0.0` and remain reachable externally.

   AI stacks auto-mount `/mnt/coldstore` for their models if that directory exists; otherwise they fall back to the default `/opt/<service>` paths included in the Compose files.

## What Each Service Provides

* **Portainer:** Web UI for monitoring the Docker host, viewing logs, and updating containers.
* **Ollama:** Local LLM runtime; **Open WebUI** adds a chat-style interface that targets Ollama's API.
* **n8n:** Workflow automation platform for connecting webhooks, APIs, and services.
* **Text Generation WebUI:** Model-agnostic chat and inference UI for local or remote LLMs.
* **LibreChat:** Full-featured chat application with history, tools, and multi-provider support (paired with bundled MongoDB, Redis, and Meilisearch containers).
* **ComfyUI:** Node-based interface for building Stable Diffusion image pipelines.
* **Stable Diffusion WebUI:** Browser UI for image generation and model management.
* **Whisper.cpp server:** Wyoming-compatible speech-to-text endpoint using lightweight Whisper models.
* **WhisperX API:** Alignment-focused speech-to-text API with diarization-ready outputs.
* **Piper TTS:** Wyoming-compatible text-to-speech server with downloadable voices.
* **Qdrant:** Vector database for semantic search and embeddings.
* **Milvus:** Scalable vector database with gRPC/HTTP APIs.
* **LangGraph Studio:** Visual editor for LangGraph agents that can call Ollama by default.
* **CrewAI orchestrator:** Backend for coordinating multi-agent LLM workflows.

## System Prerequisites
Before running Terraform, you must ensure:
1.  **SSH Access:** Keys are copied to the server (`ssh-copy-id`).
2.  **Passwordless Sudo:** The user must be able to run sudo without a password for Terraform automation.
    Run this on the server (or via SSH) once:
    ```bash
    ssh -t michael@<server-ip> "echo 'michael ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/michael"
    ```

## Bootstrapping Details
Terraform uses SSH to connect to the server. Ensure you have:
1. SSH access to the server via public key (`ssh-copy-id`).
2. Sudo privileges on the server (NOPASSWD recommended).

## Checking Logs
To check on the logs of the deployed services (example: Portainer), you can SSH into the server and run the docker logs command:

```bash
ssh michael@192.168.86.38 "sudo docker logs -f portainer"
```
