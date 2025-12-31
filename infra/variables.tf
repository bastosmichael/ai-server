variable "docker_host" {
  description = "Docker daemon socket to connect to"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "enable_portainer" {
  description = "Enable Portainer stack deployment"
  type        = bool
  default     = true
}

variable "enable_ollama" {
  description = "Enable Ollama stack deployment"
  type        = bool
  default     = false
}

variable "enable_text_generation_webui" {
  description = "Enable Text Generation WebUI deployment"
  type        = bool
  default     = false
}

variable "enable_librechat" {
  description = "Enable LibreChat deployment"
  type        = bool
  default     = false
}

variable "enable_comfyui" {
  description = "Enable ComfyUI deployment"
  type        = bool
  default     = false
}

variable "enable_stable_diffusion_webui" {
  description = "Enable Stable Diffusion WebUI deployment"
  type        = bool
  default     = false
}

variable "enable_whisper_server" {
  description = "Enable Wyoming Whisper server deployment"
  type        = bool
  default     = false
}

variable "enable_piper_tts" {
  description = "Enable Piper TTS deployment"
  type        = bool
  default     = false
}

variable "enable_qdrant" {
  description = "Enable Qdrant deployment"
  type        = bool
  default     = false
}

variable "enable_milvus" {
  description = "Enable Milvus deployment"
  type        = bool
  default     = false
}

variable "enable_langgraph_studio" {
  description = "Enable LangGraph Studio deployment"
  type        = bool
  default     = false
}

variable "enable_crewai" {
  description = "Enable CrewAI orchestrator deployment"
  type        = bool
  default     = false
}

variable "enable_n8n" {
  description = "Enable n8n deployment"
  type        = bool
  default     = false
}

variable "enable_whisperx" {
  description = "Enable WhisperX deployment"
  type        = bool
  default     = false
}
