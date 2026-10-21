import mysql from 'mysql2/promise'
import bcrypt from 'bcryptjs'
import dotenv from 'dotenv'

dotenv.config()

const baseConfig = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'root',
  multipleStatements: true
}

const dbName = process.env.DB_NAME || 'volc_ai_proxy'

async function main() {
  const conn = await mysql.createConnection(baseConfig)
  await conn.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`)
  await conn.query(`USE \`${dbName}\``)

  await conn.query(`
CREATE TABLE IF NOT EXISTS admins (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at DATETIME NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  api_key VARCHAR(128) NOT NULL UNIQUE,
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  five_hour_limit INT NOT NULL DEFAULT 50,
  daily_limit INT NOT NULL DEFAULT 100,
  weekly_limit INT NOT NULL DEFAULT 500,
  quota_mode ENUM('requests','tokens') NOT NULL DEFAULT 'requests',
  model_allowlist TEXT NULL,
  notes TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS usage_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  model VARCHAR(128) NULL,
  endpoint VARCHAR(255) NOT NULL,
  status ENUM('success','error') NOT NULL,
  http_status INT NOT NULL DEFAULT 200,
  prompt_tokens INT NOT NULL DEFAULT 0,
  completion_tokens INT NOT NULL DEFAULT 0,
  total_tokens INT NOT NULL DEFAULT 0,
  request_count INT NOT NULL DEFAULT 1,
  duration_ms INT NOT NULL DEFAULT 0,
  error_message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_usage_user_time (user_id, created_at),
  INDEX idx_usage_status_time (status, created_at),
  INDEX idx_usage_model_time (model, created_at),
  CONSTRAINT fk_usage_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS models (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  model_id VARCHAR(128) NOT NULL UNIQUE,
  display_name VARCHAR(128) NOT NULL,
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  notes TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS api_status_logs (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  target VARCHAR(128) NOT NULL,
  status ENUM('ok','error') NOT NULL,
  response_time_ms INT NOT NULL DEFAULT 0,
  message TEXT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_status_time (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
`)

  const adminUsername = process.env.ADMIN_USERNAME || 'admin'
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123'
  const hash = await bcrypt.hash(adminPassword, 10)
  const [admins] = await conn.execute('SELECT id FROM admins WHERE username = ?', [adminUsername])
  if (admins.length === 0) {
    await conn.execute('INSERT INTO admins (username, password_hash) VALUES (?, ?)', [adminUsername, hash])
    console.log(`管理员已创建: ${adminUsername} / ${adminPassword}`)
  } else {
    console.log(`管理员已存在: ${adminUsername}`)
  }

  const defaultModels = [
    ['doubao-lite-4k', 'Doubao Lite 4K'],
    ['doubao-lite-32k', 'Doubao Lite 32K'],
    ['doubao-pro-4k', 'Doubao Pro 4K'],
    ['doubao-pro-32k', 'Doubao Pro 32K']
  ]
  for (const [modelId, displayName] of defaultModels) {
    await conn.execute('INSERT IGNORE INTO models (model_id, display_name) VALUES (?, ?)', [modelId, displayName])
  }

  await conn.end()
  console.log(`数据库初始化完成: ${dbName}`)
}

main().catch((err) => {
  console.error('数据库初始化失败:', err.message)
  process.exit(1)
})
