import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { getOne, query } from '../config/db.js'

const JWT_SECRET = process.env.JWT_SECRET || 'please-change-this-secret'

export async function loginAdmin(username, password) {
  const admin = await getOne('SELECT * FROM admins WHERE username = ?', [username])
  if (!admin) return null
  const ok = await bcrypt.compare(password, admin.password_hash)
  if (!ok) return null
  await query('UPDATE admins SET last_login_at = NOW() WHERE id = ?', [admin.id])
  return jwt.sign({ id: admin.id, username: admin.username, role: 'admin' }, JWT_SECRET, { expiresIn: '24h' })
}

export function requireAdmin(req, res, next) {
  const token = req.cookies?.admin_token || (req.headers.authorization || '').replace(/^Bearer\s+/i, '')
  if (!token) return res.status(401).json({ error: '未登录' })
  try {
    req.admin = jwt.verify(token, JWT_SECRET)
    next()
  } catch (_err) {
    return res.status(401).json({ error: '登录已过期' })
  }
}

export function requireAdminPage(req, res, next) {
  const token = req.cookies?.admin_token
  if (!token) return res.redirect('/admin/login')
  try {
    req.admin = jwt.verify(token, JWT_SECRET)
    next()
  } catch (_err) {
    return res.redirect('/admin/login')
  }
}

export async function requireUserApiKey(req, res, next) {
  const auth = req.headers.authorization || ''
  const apiKey = auth.replace(/^Bearer\s+/i, '').trim()
  if (!apiKey) return res.status(401).json({ error: { message: '缺少用户 API Key', type: 'auth_error' } })
  const user = await getOne('SELECT * FROM users WHERE api_key = ?', [apiKey])
  if (!user || !user.enabled) return res.status(401).json({ error: { message: 'API Key 无效或已禁用', type: 'auth_error' } })
  req.user = user
  next()
}
