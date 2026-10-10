const base = process.env.TEST_BASE_URL || 'http://127.0.0.1:3000'

async function main() {
  const status = await fetch(`${base}/api/status`).then(r => r.json())
  console.log('status:', status)

  const login = await fetch(`${base}/api/admin/login`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: process.env.ADMIN_USERNAME || 'admin', password: process.env.ADMIN_PASSWORD || 'admin123' })
  })
  console.log('login status:', login.status)
  const cookie = login.headers.get('set-cookie')
  if (!cookie) throw new Error('登录未返回 cookie')

  const dashboard = await fetch(`${base}/api/admin/dashboard`, { headers: { cookie } }).then(r => r.json())
  console.log('dashboard:', dashboard)

  const userRes = await fetch(`${base}/api/admin/users`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', cookie },
    body: JSON.stringify({ name: 'smoke-test', api_key: 'sk-smoke-test', five_hour_limit: 3, daily_limit: 10, weekly_limit: 20 })
  })
  console.log('create user:', userRes.status, await userRes.json())

  const userStats = await fetch(`${base}/user/stats`, { headers: { Authorization: 'Bearer sk-smoke-test' } }).then(r => r.json())
  console.log('user stats:', userStats)
}

main().catch(err => { console.error(err); process.exit(1) })
