import express from 'express'
import { nanoid } from 'nanoid'
import { loginAdmin, requireAdmin } from '../middleware/auth.js'
import { getOne, query } from '../config/db.js'
import { getQuotaSnapshot } from '../services/quotaService.js'
import { checkArkStatus } from '../services/volcService.js'

export const adminRouter = express.Router()

adminRouter.post('/login', async (req, res) => {
  const token = await loginAdmin(req.body.username || '', req.body.password || '')
  if (!token) return res.status(401).json({ error: '用户名或密码错误' })
  res.cookie('admin_token', token, { httpOnly: true, sameSite: 'lax', maxAge: 24 * 60 * 60 * 1000 })
  res.json({ ok: true })
})

adminRouter.post('/logout', (_req, res) => {
  res.clearCookie('admin_token')
  res.json({ ok: true })
})

adminRouter.get('/me', requireAdmin, (req, res) => res.json({ admin: req.admin }))

adminRouter.get('/dashboard', requireAdmin, async (_req, res) => {
  const [users, today, week, errors, avg] = await Promise.all([
    getOne('SELECT COUNT(*) AS count FROM users'),
    getOne('SELECT COUNT(*) AS count FROM usage_logs WHERE created_at >= CURDATE()'),
    getOne('SELECT COUNT(*) AS count FROM usage_logs WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)'),
    getOne("SELECT COUNT(*) AS count FROM usage_logs WHERE status = 'error' AND created_at >= CURDATE()"),
    getOne('SELECT ROUND(AVG(duration_ms), 0) AS avg_ms FROM usage_logs WHERE created_at >= CURDATE()')
  ])
  res.json({
    totalUsers: Number(users?.count || 0),
    todayRequests: Number(today?.count || 0),
    weeklyRequests: Number(week?.count || 0),
    todayErrors: Number(errors?.count || 0),
    avgLatencyMs: Number(avg?.avg_ms || 0)
  })
})

adminRouter.get('/users', requireAdmin, async (_req, res) => {
  const users = await query('SELECT * FROM users ORDER BY id DESC')
  const enriched = []
  for (const user of users) enriched.push({ ...user, quota: await getQuotaSnapshot(user) })
  res.json({ users: enriched })
})

adminRouter.post('/users', requireAdmin, async (req, res) => {
  const apiKey = req.body.api_key || `sk-local-${nanoid(24)}`
  await query(
    `INSERT INTO users (name, api_key, five_hour_limit, daily_limit, weekly_limit, quota_mode, model_allowlist, notes)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      req.body.name || '未命名用户', apiKey,
      Number(req.body.five_hour_limit || process.env.DEFAULT_FIVE_HOUR_LIMIT || 50),
      Number(req.body.daily_limit || process.env.DEFAULT_DAILY_LIMIT || 100),
      Number(req.body.weekly_limit || process.env.DEFAULT_WEEKLY_LIMIT || 500),
      req.body.quota_mode || 'requests',
      req.body.model_allowlist || null,
      req.body.notes || null
    ]
  )
  res.json({ ok: true, api_key: apiKey })
})

adminRouter.put('/users/:id', requireAdmin, async (req, res) => {
  await query(
    `UPDATE users SET name=?, enabled=?, five_hour_limit=?, daily_limit=?, weekly_limit=?, quota_mode=?, model_allowlist=?, notes=? WHERE id=?`,
    [req.body.name, Number(req.body.enabled ? 1 : 0), Number(req.body.five_hour_limit), Number(req.body.daily_limit), Number(req.body.weekly_limit), req.body.quota_mode, req.body.model_allowlist || null, req.body.notes || null, req.params.id]
  )
  res.json({ ok: true })
})

adminRouter.delete('/users/:id', requireAdmin, async (req, res) => {
  await query('DELETE FROM users WHERE id=?', [req.params.id])
  res.json({ ok: true })
})

adminRouter.post('/users/:id/reset-key', requireAdmin, async (req, res) => {
  const apiKey = `sk-local-${nanoid(24)}`
  await query('UPDATE users SET api_key=? WHERE id=?', [apiKey, req.params.id])
  res.json({ ok: true, api_key: apiKey })
})

adminRouter.get('/logs', requireAdmin, async (req, res) => {
  const limit = Math.min(Number(req.query.limit || 100), 500)
  const logs = await query(
    `SELECT l.*, u.name AS user_name FROM usage_logs l JOIN users u ON u.id = l.user_id ORDER BY l.id DESC LIMIT ${limit}`
  )
  res.json({ logs })
})

adminRouter.get('/models', requireAdmin, async (_req, res) => {
  const models = await query('SELECT * FROM models ORDER BY id ASC')
  res.json({ models })
})

adminRouter.post('/models', requireAdmin, async (req, res) => {
  await query('INSERT INTO models (model_id, display_name, enabled, notes) VALUES (?, ?, ?, ?)', [req.body.model_id, req.body.display_name, Number(req.body.enabled ? 1 : 0), req.body.notes || null])
  res.json({ ok: true })
})

adminRouter.get('/status', requireAdmin, async (_req, res) => {
  const started = Date.now()
  const dbOk = await getOne('SELECT 1 AS ok')
  const ark = await checkArkStatus()
  await query('INSERT INTO api_status_logs (target, status, response_time_ms, message) VALUES (?, ?, ?, ?)', [ark.target, ark.status, ark.response_time_ms, ark.message])
  res.json({ server: { status: 'ok', response_time_ms: Date.now() - started }, database: { status: dbOk?.ok ? 'ok' : 'error' }, ark })
})
