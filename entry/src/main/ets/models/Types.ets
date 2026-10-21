export interface RunRequest {
  feature: string
  params: Record<string, Object>
}

export interface RunResponse {
  ok: boolean
  data?: Record<string, Object>
  error?: string
}

export interface AuthSessionResponse {
  ok: boolean
  data?: Record<string, Object>
  error?: string
}

export interface CallResultOk {
  ok: boolean
  data: Record<string, Object>
}

export interface CallResultErr {
  ok: boolean
  error: string
}

export interface FeatureDef {
  name: string
  title: string
  system: string
  icon: string
  page: string
}
