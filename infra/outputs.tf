locals {
  docker_host_address = var.docker_host != "unix:///var/run/docker.sock" ? replace(replace(var.docker_host, "ssh://", ""), "michael@", "") : "localhost"
}

output "portainer_url" {
  description = "URL to access Portainer"
  value       = var.enable_portainer ? "http://${local.docker_host_address}:9000" : "Portainer not enabled"
}

output "ollama_url" {
  description = "URL to access Ollama API"
  value       = var.enable_ollama ? "http://${local.docker_host_address}:11434" : "Ollama not enabled"
}

output "deployed_stacks" {
  description = "List of deployed stacks"
  value = concat(
    var.enable_portainer ? ["portainer"] : [],
    var.enable_ollama ? ["ollama"] : [],
    var.enable_n8n ? ["n8n"] : [],
    var.enable_text_generation_webui ? ["text-generation-webui"] : [],
    var.enable_librechat ? ["librechat"] : [],
    var.enable_comfyui ? ["comfyui"] : [],
    var.enable_stable_diffusion_webui ? ["stable-diffusion-webui"] : [],
    var.enable_whisper_server ? ["whisper-server"] : [],
    var.enable_whisperx ? ["whisperx"] : [],
    var.enable_piper_tts ? ["piper-tts"] : [],
    var.enable_qdrant ? ["qdrant"] : [],
    var.enable_milvus ? ["milvus"] : [],
    var.enable_langgraph_studio ? ["langgraph-studio"] : [],
    var.enable_crewai ? ["crewai"] : []
  )
}
