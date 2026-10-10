import { getOne, query } from '../config/db.js'

function valueExpr(mode) {
  return mode === 'tokens' ? 'COALESCE(SUM(total_tokens), 0)' : 'COALESCE(SUM(request_count), 0)'
}

export async function getQuotaSnapshot(user) {
  const expr = valueExpr(user.quota_mode)
  const [five, day, week] = await Promise.all([
    getOne(`SELECT ${expr} AS used FROM usage_logs WHERE user_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 5 HOUR)`, [user.id]),
    getOne(`SELECT ${expr} AS used FROM usage_logs WHERE user_id = ? AND created_at >= CURDATE()`, [user.id]),
    getOne(`SELECT ${expr} AS used FROM usage_logs WHERE user_id = ? AND created_at >= DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)`, [user.id])
  ])
  const fiveUsed = Number(five?.used || 0)
  const dailyUsed = Number(day?.used || 0)
  const weeklyUsed = Number(week?.used || 0)
  return {
    mode: user.quota_mode,
    fiveHour: { used: fiveUsed, limit: user.five_hour_limit, remaining: Math.max(user.five_hour_limit - fiveUsed, 0) },
    daily: { used: dailyUsed, limit: user.daily_limit, remaining: Math.max(user.daily_limit - dailyUsed, 0) },
    weekly: { used: weeklyUsed, limit: user.weekly_limit, remaining: Math.max(user.weekly_limit - weeklyUsed, 0) }
  }
}

export async function assertQuota(user) {
  const snapshot = await getQuotaSnapshot(user)
  if (snapshot.fiveHour.used >= snapshot.fiveHour.limit) {
    return { ok: false, status: 429, message: '5小时额度已用完', quota: snapshot, resetHint: '滚动窗口：当前时间往前5小时内用量下降后恢复' }
  }
  if (snapshot.daily.used >= snapshot.daily.limit) {
    return { ok: false, status: 429, message: '今日额度已用完', quota: snapshot, resetHint: '明日 00:00 后恢复' }
  }
  if (snapshot.weekly.used >= snapshot.weekly.limit) {
    return { ok: false, status: 429, message: '本周额度已用完', quota: snapshot, resetHint: '下周一 00:00 后恢复' }
  }
  return { ok: true, quota: snapshot }
}

export async function writeUsageLog({ userId, model, endpoint, status, httpStatus, usage, durationMs, errorMessage }) {
  await query(
    `INSERT INTO usage_logs
     (user_id, model, endpoint, status, http_status, prompt_tokens, completion_tokens, total_tokens, request_count, duration_ms, error_message)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`,
    [
      userId,
      model || null,
      endpoint,
      status,
      httpStatus || 200,
      Number(usage?.prompt_tokens || 0),
      Number(usage?.completion_tokens || 0),
      Number(usage?.total_tokens || 0),
      durationMs || 0,
      errorMessage || null
    ]
  )
}
