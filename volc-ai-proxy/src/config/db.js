import mysql from 'mysql2/promise'
import dotenv from 'dotenv'

dotenv.config()

export const dbConfig = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'root',
  database: process.env.DB_NAME || 'volc_ai_proxy',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  timezone: '+08:00'
}

export const pool = mysql.createPool(dbConfig)

export async function query(sql, params = []) {
  const [rows] = await pool.execute(sql, params)
  return rows
}

export async function getOne(sql, params = []) {
  const rows = await query(sql, params)
  return rows[0] || null
}
