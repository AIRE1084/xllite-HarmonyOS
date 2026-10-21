import express from 'express'
import { requireUserApiKey } from '../middleware/auth.js'
import { assertQuota, getQuotaSnapshot, writeUsageLog } from '../services/quotaService.js'
import { forwardToArk } from '../services/volcService.js'

export const proxyRouter = express.Router()

proxyRouter.get('/user/stats', requireUserApiKey, async (req, res) => {
  res.json({ user: { id: req.user.id, name: req.user.name, quota_mode: req.user.quota_mode }, quota: await getQuotaSnapshot(req.user) })
})

proxyRouter.all('/v1/*', requireUserApiKey, async (req, res) => {
  const quota = await assertQuota(req.user)
  if (!quota.ok) {
    return res.status(quota.status).json({ error: { message: quota.message, type: 'quota_exceeded', reset_hint: quota.resetHint, quota: quota.quota } })
  }

  const allowlist = (req.user.model_allowlist || '').split(',').map(x => x.trim()).filter(Boolean)
  const model = req.body?.model || req.query?.model || null
  if (allowlist.length > 0 && model && !allowlist.includes(model)) {
    return res.status(403).json({ error: { message: `该用户不允许调用模型：${model}`, type: 'model_forbidden' } })
  }

  const started = Date.now()
  try {
    const result = await forwardToArk(req)
    const usage = result.data?.usage || {}
    await writeUsageLog({ userId: req.user.id, model, endpoint: req.originalUrl, status: result.httpStatus >= 200 && result.httpStatus < 400 ? 'success' : 'error', httpStatus: result.httpStatus, usage, durationMs: Date.now() - started, errorMessage: result.httpStatus >= 400 ? JSON.stringify(result.data).slice(0, 1000) : null })
    res.status(result.httpStatus).json(result.data)
  } catch (err) {
    await writeUsageLog({ userId: req.user.id, model, endpoint: req.originalUrl, status: 'error', httpStatus: err.response?.status || 500, usage: {}, durationMs: Date.now() - started, errorMessage: err.message })
    res.status(err.response?.status || 500).json(err.response?.data || { error: { message: err.message, type: 'proxy_error' } })
  }
})
