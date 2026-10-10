import express from 'express'
import cors from 'cors'
import cookieParser from 'cookie-parser'
import rateLimit from 'express-rate-limit'
import dotenv from 'dotenv'
import path from 'path'
import { fileURLToPath } from 'url'
import { adminRouter } from './routes/adminRoutes.js'
import { proxyRouter } from './routes/proxyRoutes.js'
import { requireAdminPage } from './middleware/auth.js'
import { logger } from './utils/logger.js'

dotenv.config()

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const app = express()
const port = Number(process.env.PORT || 3000)

app.use(cors())
app.use(express.json({ limit: '2mb' }))
app.use(cookieParser())
app.use(rateLimit({ windowMs: 60 * 1000, limit: 300 }))
app.use(express.static(path.join(__dirname, 'public')))

app.get('/', (_req, res) => res.redirect('/admin'))
app.get('/admin/login', (_req, res) => res.sendFile(path.join(__dirname, 'public', 'login.html')))
app.get('/admin', requireAdminPage, (_req, res) => res.sendFile(path.join(__dirname, 'public', 'index.html')))
app.get('/api/status', (_req, res) => res.json({ status: 'ok', service: 'volc-ai-proxy', time: new Date().toISOString() }))

app.use('/api/admin', adminRouter)
app.use('/', proxyRouter)

app.use((err, _req, res, _next) => {
  logger.error(err)
  res.status(500).json({ error: { message: err.message || '服务器内部错误', type: 'internal_error' } })
})

app.listen(port, '0.0.0.0', () => {
  logger.info(`Volc AI Proxy started: http://localhost:${port}`)
  logger.info(`Admin: http://localhost:${port}/admin`)
})
