import axios from 'axios'

const ARK_BASE_URL = process.env.ARK_BASE_URL || 'https://ark.cn-beijing.volces.com/api/v3'

export function isArkConfigured() {
  const key = process.env.ARK_API_KEY || ''
  return key && !key.includes('填你的')
}

export async function forwardToArk(req) {
  if (!isArkConfigured()) {
    return {
      data: {
        id: 'mock-' + Date.now(),
        object: 'chat.completion',
        created: Math.floor(Date.now() / 1000),
        model: req.body?.model || 'mock-model',
        choices: [{ index: 0, message: { role: 'assistant', content: 'Mock 模式：请在 .env 中填写 ARK_API_KEY 后启用真实中转。' }, finish_reason: 'stop' }],
        usage: { prompt_tokens: 8, completion_tokens: 18, total_tokens: 26 }
      },
      httpStatus: 200
    }
  }

  const url = `${ARK_BASE_URL}${req.originalUrl.replace(/^\/v1/, '')}`
  const response = await axios({
    method: req.method,
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.ARK_API_KEY}`
    },
    data: req.body,
    timeout: 120000,
    validateStatus: () => true
  })
  return { data: response.data, httpStatus: response.status }
}

export async function checkArkStatus() {
  const started = Date.now()
  if (!isArkConfigured()) {
    return { target: 'ark', status: 'ok', response_time_ms: 0, message: 'Mock 模式，未配置 ARK_API_KEY' }
  }
  try {
    const response = await axios.get(`${ARK_BASE_URL}/models`, {
      headers: { Authorization: `Bearer ${process.env.ARK_API_KEY}` },
      timeout: 15000,
      validateStatus: () => true
    })
    return {
      target: 'ark',
      status: response.status >= 200 && response.status < 500 ? 'ok' : 'error',
      response_time_ms: Date.now() - started,
      message: `HTTP ${response.status}`
    }
  } catch (err) {
    return { target: 'ark', status: 'error', response_time_ms: Date.now() - started, message: err.message }
  }
}
