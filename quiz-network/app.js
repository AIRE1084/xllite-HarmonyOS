/* ==========================================================================
   计算机网络刷题站 v2 — 主逻辑
   - SRS 间隔重复 (SM-2 简化)
   - 7 模式：顺序/随机/错题/收藏/专项/SRS/考试
   - 8 题型：single/multi/tf/fill/short/comp/sort/match
   - SVG 自绘统计图 (雷达/折线/柱状)
   - JSON 题库导入
   - localStorage key = 'network-quiz-v2'
   - 兼容 v1 数据迁移
   ========================================================================== */
(function () {
'use strict';

/* --------------------------------------------------------------------------
   0. 常量 & 工具
   -------------------------------------------------------------------------- */
const STORE_KEY = 'network-quiz-v2';
const OLD_KEY   = 'network-quiz-v1';
const DAY_MS    = 86400e3;
const STORE_VERSION = 2;

const $  = (s, el=document) => el.querySelector(s);
const $$ = (s, el=document) => Array.from(el.querySelectorAll(s));
const escapeHtml = s => String(s ?? '').replace(/[&<>"']/g, c =>
  ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const norm = s => String(s ?? '').trim().replace(/\s+/g,'').toLowerCase();
const fmtTime = sec => {
  sec = Math.max(0, Math.floor(sec));
  const m = Math.floor(sec / 60), s = sec % 60;
  return String(m).padStart(2,'0') + ':' + String(s).padStart(2,'0');
};
const fmtDay = ts => {
  if (!ts) return '—';
  const d = new Date(ts), now = new Date();
  const diff = Math.round((d - now) / DAY_MS);
  const today = d.toDateString() === now.toDateString();
  if (today) return '今天';
  if (diff === 1) return '明天';
  if (diff === -1) return '昨天';
  if (diff > 0) return diff + ' 天后';
  if (diff < 0) return Math.abs(diff) + ' 天前';
  return `${d.getMonth()+1}/${d.getDate()}`;
};
const arrEq = (a, b) => a.length === b.length && a.every((x,i) => x === b[i]);
const setEq = (a, b) => {
  const sa = new Set(a), sb = new Set(b);
  return sa.size === sb.size && [...sa].every(x => sb.has(x));
};
const shuffle = arr => {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

/* --------------------------------------------------------------------------
   1. 默认状态
   -------------------------------------------------------------------------- */
function defaultState() {
  return {
    version: STORE_VERSION,
    schema: { questions: QUESTIONS.slice(), categories: CATEGORIES, typeLabel: TYPE_LABEL },
    perQuestion: {},
    session: { mode: 'sequential', category: '', type: '', search: '' },
    exam: { active: false, queue: [], idx: 0, startTs: 0, timeLimit: 0, answers: {} },
    sessions: []
  };
}

/* --------------------------------------------------------------------------
   2. 存储 + v1 → v2 迁移
   -------------------------------------------------------------------------- */
let state = loadState();
function loadState() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) {
      const obj = JSON.parse(raw);
      const d = defaultState();
      const sess = Object.assign(d.session, obj.session || {});
      // 不要从 localStorage 恢复 exam 模式（考试结束应回到顺序）
      if (sess.mode === 'exam') sess.mode = 'sequential';
      return {
        version: STORE_VERSION,
        schema: obj.schema || d.schema,
        perQuestion: obj.perQuestion || {},
        session: sess,
        exam: { active: false, queue: [], idx: 0, startTs: 0, timeLimit: 0, answers: {} },
        sessions: obj.sessions || []
      };
    }
    // 尝试从 v1 迁移
    const old = localStorage.getItem(OLD_KEY);
    if (old) {
      const obj = JSON.parse(old);
      // v1 没有 schema 字段，保留 QUESTIONS 默认；perQuestion 字段兼容（用 qN 新 id 重映射或按 no 关联）
      const migrated = defaultState();
      const byNo = {};
      QUESTIONS.forEach(q => { byNo[`n:${q.no}:${q.type}`] = q.id; });
      if (obj.perQuestion) {
        Object.entries(obj.perQuestion).forEach(([k, v]) => {
          // v1 key 是 id (s24, t17, f6, h1, c5)，映射到新 id
          if (QUESTIONS.find(q => q.id === k)) {
            migrated.perQuestion[k] = Object.assign({ srs: DEFAULT_SRS() }, v);
          }
        });
      }
      if (obj.session) migrated.session = Object.assign(migrated.session, obj.session);
      return migrated;
    }
  } catch (e) {
    console.warn('loadState failed', e);
  }
  return defaultState();
}

let saveTimer = null;
function saveState() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    try { localStorage.setItem(STORE_KEY, JSON.stringify(state)); }
    catch (e) { console.warn('saveState failed', e); }
  }, 200);
}
function resetAll() {
  if (!confirm('确定要清空所有学习记录、收藏、错题、笔记吗？此操作不可撤销。')) return;
  state = defaultState();
  saveState();
  applySettings();
  refreshAll();
  toast('已重置');
}

/* 获取题目（优先用用户导入的 schema） */
function activeQuestions() {
  return (state.schema && state.schema.questions && state.schema.questions.length)
    ? state.schema.questions : QUESTIONS;
}
function activeCategories() {
  return (state.schema && state.schema.categories) || CATEGORIES;
}
function activeTypeLabel() {
  return (state.schema && state.schema.typeLabel) || TYPE_LABEL;
}

/* --------------------------------------------------------------------------
   3. SRS 算法 (SM-2 简化版)
   grade: 0(重来) | 1(困难) | 2(良好) | 3(简单)
   -------------------------------------------------------------------------- */
function srsUpdate(card, grade) {
  let ef = card.ef ?? 2.5;
  let interval = card.interval ?? 0;
  let reps = card.reps ?? 0;
  let lapses = card.lapses ?? 0;
  if (grade < 2) {
    lapses++;
    reps = 0;
    interval = 1;
    ef = Math.max(1.3, ef - 0.2);
  } else {
    reps++;
    if (reps === 1) interval = 1;
    else if (reps === 2) interval = 3;
    else interval = Math.round(interval * ef);
    ef = ef + (0.1 - (3 - grade) * (0.08 + (3 - grade) * 0.02));
    if (grade === 3) ef += 0.15;
  }
  ef = Math.round(ef * 100) / 100;
  return {
    ef, interval, reps, lapses,
    due: Date.now() + interval * DAY_MS,
    lastGrade: grade,
    lastTs: Date.now()
  };
}

function getCard(id) {
  if (!state.perQuestion[id]) {
    state.perQuestion[id] = {
      attempts: 0, correct: 0, wrong: 0, fav: false, review: false,
      userNote: '', selfRate: null,
      srs: DEFAULT_SRS()
    };
  }
  if (!state.perQuestion[id].srs) state.perQuestion[id].srs = DEFAULT_SRS();
  return state.perQuestion[id];
}

function dueCount() {
  const now = Date.now();
  return activeQuestions().filter(q => {
    const c = state.perQuestion[q.id];
    return c && c.srs && c.srs.due && c.srs.due <= now && (c.attempts || 0) > 0;
  }).length;
}

/* --------------------------------------------------------------------------
   4. 设置（主题 / 字号）
   -------------------------------------------------------------------------- */
function applySettings() {
  document.body.dataset.theme = state.session.theme || 'light';
  document.body.dataset.fontsize = state.session.font || 'md';
  $('#themeBtn').textContent = state.session.theme === 'dark' ? '☀' : '🌗';
}
$('#themeBtn').addEventListener('click', () => {
  state.session.theme = state.session.theme === 'dark' ? 'light' : 'dark';
  applySettings(); saveState();
});
$('#fontBtn').addEventListener('click', () => {
  const order = ['sm', 'md', 'lg'];
  const i = order.indexOf(state.session.font || 'md');
  state.session.font = order[(i + 1) % order.length];
  applySettings(); saveState();
  toast('字号：' + ({sm:'小', md:'中', lg:'大'}[state.session.font]));
});

/* --------------------------------------------------------------------------
   5. 题库过滤器（按模式 / 分类 / 题型 / 搜索）
   -------------------------------------------------------------------------- */
function getPool() {
  const sess = state.session;
  const QS = activeQuestions();
  const now = Date.now();
  let pool;
  if (sess.mode === 'wrong') {
    pool = QS.filter(q => (state.perQuestion[q.id]?.wrong || 0) > 0);
  } else if (sess.mode === 'fav') {
    pool = QS.filter(q => state.perQuestion[q.id]?.fav);
  } else if (sess.mode === 'category') {
    pool = sess.category ? QS.filter(q => q.cat === sess.category) : QS.slice();
  } else if (sess.mode === 'srs') {
    pool = QS.filter(q => {
      const c = state.perQuestion[q.id];
      return c && c.attempts > 0 && c.srs && c.srs.due && c.srs.due <= now;
    });
    pool.sort((a, b) => (state.perQuestion[a.id].srs.due || 0) - (state.perQuestion[b.id].srs.due || 0));
  } else {
    pool = QS.slice();
  }
  if (sess.type)   pool = pool.filter(q => q.type === sess.type);
  if (sess.search) {
    const k = sess.search.trim().toLowerCase();
    // 支持 qN 直接跳转
    const qMatch = /^q(\d+)$/i.exec(k);
    if (qMatch) {
      const q = QS.find(qq => qq.id === 'q' + qMatch[1]);
      pool = q ? [q] : [];
    } else {
      pool = pool.filter(q => {
        if (q.stem.toLowerCase().includes(k)) return true;
        if (q.options?.some(o => o.t.toLowerCase().includes(k))) return true;
        if ((q.refAnswer || '').toLowerCase().includes(k)) return true;
        if ((q.answer || []).join(',').toLowerCase().includes(k)) return true;
        if (q.parts?.some(p => (p.stem + p.refAnswer).toLowerCase().includes(k))) return true;
        if (q.matchPairs?.some(p => (p.left + p.right).toLowerCase().includes(k))) return true;
        if (q.sortItems?.some(p => p.t.toLowerCase().includes(k))) return true;
        return false;
      });
    }
  }
  return pool;
}

/* --------------------------------------------------------------------------
   6. 当前题 & 模式驱动
   -------------------------------------------------------------------------- */
let currentList = [];
let currentIdx = 0;
let current = null;
let sessionCorrect = 0;
let sessionDone = 0;
let showAnswerNow = false;
let currentPick = null;

function rebuildList() {
  const sess = state.session;
  let pool = getPool();
  if (sess.mode === 'random' || sess.mode === 'wrong' || sess.mode === 'fav' || sess.mode === 'category') {
    pool = shuffle(pool);
  } else if (sess.mode === 'exam') {
    pool = shuffle(pool);
    state.exam.active = true;
    state.exam.queue = pool.map(q => q.id);
    state.exam.idx = 0;
    state.exam.answers = {};
    state.exam.startTs = Date.now();
    state.exam.timeLimit = Math.max(1, pool.length) * 90;
  }
  if (sess.mode !== 'exam') {
    state.exam.active = false;
    state.exam.queue = [];
  }
  currentList = pool;
  currentIdx = 0;
  sessionCorrect = 0;
  sessionDone = 0;
}

function startSession() {
  rebuildList();
  renderCurrent();
  refreshNav();
  refreshProgress();
  refreshDuePill();
}

function setMode(mode) {
  state.session.mode = mode;
  if (mode !== 'category') state.session.category = '';
  if (mode !== 'srs' && mode !== 'category') {
    // 不重置搜索/题型,保留用户筛选
  }
  saveState();
  startSession();
}

function applyFilter() {
  state.session.search = $('#searchInput').value.trim();
  state.session.type = $('#filterType').value;
  state.session.category = $('#filterCat').value;
  saveState();
  startSession();
}

/* --------------------------------------------------------------------------
   7. 渲染：导航 / 题号网格 / 进度
   -------------------------------------------------------------------------- */
function refreshNav() {
  $$('#modeGrid .mode-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.mode === state.session.mode);
  });
  const CATS = activeCategories();
  const TLABEL = activeTypeLabel();
  const modeNames = { sequential:'顺序练习', random:'随机练习', wrong:'错题重练',
                      fav:'收藏复习', category:'专项突破', srs:'SRS 复习', exam:'模拟考试' };
  $('#modeTag').textContent = modeNames[state.session.mode] || '';
  $('#catTag').textContent = state.session.category ? (CATS[state.session.category] || state.session.category) : '—';
  const tagBits = [];
  if (state.session.type) tagBits.push(TLABEL[state.session.type] || state.session.type);
  if (state.session.search) tagBits.push('🔍 ' + state.session.search);
  $('#filterTag').textContent = tagBits.join(' · ') || '—';
  $('#sessionMeta').textContent = `${currentList.length} 题`;
  $('#curIdx').textContent = currentList.length ? (currentIdx + 1) : 0;
  $('#curTotal').textContent = currentList.length;

  const isExam = state.exam.active;
  $('#timerWrap').hidden = !isExam;
  if (isExam) startExamTimer();
  else stopExamTimer();

  const qnav = $('#qnav');
  qnav.innerHTML = '';
  const now = Date.now();
  currentList.forEach((q, i) => {
    const b = document.createElement('button');
    b.innerHTML = `<span class="qno">${q.no}</span><span class="qid">q${q.id.slice(1)}</span>`;
    b.title = `${TLABEL[q.type] || q.type} · ${CATS[q.cat] || q.cat} · 原号 ${q.no} (${q.id})`;
    const r = state.perQuestion[q.id] || {};
    if (i === currentIdx) b.classList.add('cur');
    if (r.fav) b.classList.add('fav');
    if (r.review) b.classList.add('review');
    if ((r.correct || 0) > 0) b.classList.add('done');
    else if ((r.wrong || 0) > 0) b.classList.add('wrong');
    if (r.srs && r.srs.due && r.srs.due <= now && (r.attempts || 0) > 0) b.classList.add('due');
    b.addEventListener('click', () => { currentIdx = i; renderCurrent(); refreshNav(); refreshProgress(); });
    qnav.appendChild(b);
  });
}

function refreshProgress() {
  const total = currentList.length;
  $('#totalCount').textContent = total;
  let done = 0, correct = 0;
  currentList.forEach(q => {
    const r = state.perQuestion[q.id] || {};
    const seen = (r.correct || 0) + (r.wrong || 0);
    if (seen) done++;
    if ((r.correct || 0) > 0) correct++;
  });
  $('#doneCount').textContent = done;
  const pct = total ? Math.round(done * 100 / total) : 0;
  $('#progressBar').style.width = pct + '%';
  $('#accRate').textContent = done ? Math.round(correct * 100 / done) + '%' : '—';
}

function refreshDuePill() {
  const n = dueCount();
  $('#dueCount').textContent = n;
  const pill = $('#duePill');
  if (n > 0) {
    pill.style.display = 'flex';
  } else {
    pill.style.display = 'flex';
  }
}

/* --------------------------------------------------------------------------
   8. 渲染：当前题
   -------------------------------------------------------------------------- */
function renderCurrent() {
  const area = $('#qArea');
  if (!currentList.length) {
    area.innerHTML = `
      <div class="card">
        <div class="empty">
          <h2>${emptyTitle()}</h2>
          <p>${emptyHint()}</p>
        </div>
      </div>`;
    refreshActionButtons();
    return;
  }
  current = currentList[currentIdx];
  showAnswerNow = false;
  currentPick = null;
  const r = state.perQuestion[current.id] || {};
  const TLABEL = activeTypeLabel();
  const CATS = activeCategories();
  area.innerHTML = `
    <article class="card" id="qCard">
      <div style="display:flex; gap:6px; flex-wrap:wrap; margin-bottom:8px; align-items:center;">
        <span class="tag type-${current.type}">${TLABEL[current.type] || current.type}</span>
        <span class="tag cat">${CATS[current.cat] || current.cat}</span>
        <span class="tag diff-${current.diff}">${'★'.repeat(current.diff)}</span>
        <span class="tag">第 ${current.no} 题 · q${current.id.slice(1)}</span>
        ${r.attempts ? `<span class="tag">作答 ${r.attempts} · 对 ${r.correct || 0} · 错 ${r.wrong || 0}</span>` : ''}
        ${r.srs && r.srs.due ? `<span class="tag">SRS: ${fmtDay(r.srs.due)} (间隔 ${r.srs.interval}d)</span>` : ''}
        ${r.fav ? `<span class="tag" style="color:var(--amber); border-color:var(--amber);">★</span>` : ''}
        ${r.review ? `<span class="tag" style="color:var(--orange); border-color:var(--orange);">!</span>` : ''}
      </div>
      <div class="stem">${escapeHtml(current.stem)}</div>
      <div id="qBody"></div>
      <div id="answerBox"></div>
      <div class="action-row">
        <div>
          <button class="primary" id="submitBtn">提交答案 <span class="kbd">Enter</span></button>
        </div>
        <div class="grow"></div>
        <div>
          <button id="clearPick" class="ghost">清除选择</button>
        </div>
      </div>
    </article>
    <article class="card">
      <h3>📝 我的笔记</h3>
      <textarea id="userNote" placeholder="记下针对本题的笔记 / 易错点 / 助记口诀...">${escapeHtml(r.userNote || '')}</textarea>
    </article>
  `;
  renderQuestionBody();
  bindCardEvents();
  refreshActionButtons();
  refreshNav();
  refreshProgress();
}

function refreshActionButtons() {
  const r = current ? (state.perQuestion[current.id] || {}) : {};
  $('#favBtn').classList.toggle('warn', !!r.fav);
  $('#favBtn').textContent = r.fav ? '★ 已收藏' : '★ 收藏';
  $('#reviewBtn').classList.toggle('warn', !!r.review);
  $('#reviewBtn').textContent = r.review ? '! 已标记' : '! 待复习';
  $('#prevBtn').disabled = currentIdx <= 0;
  $('#nextBtn').disabled = currentIdx >= currentList.length - 1;
  $('#showAnsBtn').textContent = showAnswerNow ? '隐藏答案' : '显示答案';
}

function emptyTitle() {
  if (state.session.mode === 'wrong') return '还没有错题 🎉';
  if (state.session.mode === 'fav')   return '暂无收藏题';
  if (state.session.mode === 'srs')   return '今日无 SRS 复习题 📅';
  if (state.session.search || state.session.type || state.session.category) return '没有匹配的题目';
  return '题库为空';
}
function emptyHint() {
  if (state.session.mode === 'wrong') return '切换到「顺序练习」开始,做错的题会自动收集到这里。';
  if (state.session.mode === 'fav')   return '在题目上点击「★ 收藏」可加入这里。';
  if (state.session.mode === 'srs')   return '先去做题,SRS 会按遗忘曲线自动安排复习。';
  return '试试切换模式或清空筛选。';
}

/* --------------------------------------------------------------------------
   9. 题型渲染
   -------------------------------------------------------------------------- */
function renderQuestionBody() {
  const body = $('#qBody');
  const t = current.type;
  if (t === 'single') return renderSingle(body);
  if (t === 'multi')  return renderMulti(body);
  if (t === 'tf')     return renderTF(body);
  if (t === 'fill')   return renderFill(body);
  if (t === 'short')  return renderShort(body);
  if (t === 'comp')   return renderComp(body);
  if (t === 'sort')   return renderSort(body);
  if (t === 'match')  return renderMatch(body);
}

function renderSingle(body) {
  body.innerHTML = `<div class="options" id="optList">${
    current.options.map(o => `
      <label data-k="${o.k}">
        <input type="radio" name="opt" value="${o.k}">
        <span class="k">${o.k}</span>
        <span>${escapeHtml(o.t)}</span>
      </label>`).join('')
  }</div>`;
  $$('#optList label').forEach(lab => {
    lab.addEventListener('click', () => {
      $$('#optList label').forEach(x => x.classList.remove('sel'));
      lab.classList.add('sel');
      currentPick = lab.dataset.k;
    });
  });
}

function renderMulti(body) {
  body.innerHTML = `<div class="options" id="optList">${
    current.options.map(o => `
      <label data-k="${o.k}">
        <input type="checkbox" name="opt" value="${o.k}">
        <span class="k">${o.k}</span>
        <span>${escapeHtml(o.t)}</span>
      </label>`).join('')
  }</div>
  <div class="note-box">💡 多选题:勾选你认为正确的所有选项(顺序无关)</div>`;
  currentPick = [];
  $$('#optList label').forEach(lab => {
    lab.addEventListener('click', e => {
      // 让 checkbox 自然处理,但要更新 currentPick
      const cb = lab.querySelector('input');
      setTimeout(() => {
        const checked = $$('#optList input:checked').map(i => i.value);
        currentPick = checked;
        $$('#optList label').forEach(l => l.classList.toggle('sel', !!l.querySelector('input:checked')));
      }, 0);
    });
  });
}

function renderTF(body) {
  body.innerHTML = `
    <div class="tf-row">
      <button data-pick="T">✓ 对（正确） <span class="kbd">5</span></button>
      <button data-pick="F">✗ 错（错误） <span class="kbd">6</span></button>
    </div>`;
  $$('.tf-row button').forEach(b => {
    b.addEventListener('click', () => {
      $$('.tf-row button').forEach(x => x.classList.remove('sel'));
      b.classList.add('sel');
      currentPick = b.dataset.pick;
    });
  });
}

function renderFill(body) {
  body.innerHTML = `<div class="fill-row">${
    current.blanks.map((b, i) => `
      <div class="item">
        <label>第 ${i + 1} 空</label>
        <input type="text" data-bi="${i}" placeholder="在此输入答案">
      </div>`).join('')
  }</div>`;
  currentPick = current.blanks.map(() => '');
  $$('.fill-row input').forEach(inp => {
    inp.addEventListener('input', e => {
      currentPick[Number(e.target.dataset.bi)] = e.target.value;
    });
  });
}

function renderShort(body) {
  body.innerHTML = `
    <textarea id="shortAns" placeholder="在这里写下你的答案,做完点「显示答案」对照参考与得分点。"></textarea>
    <div class="action-row" style="border:0; padding-top:8px; margin-top:8px;">
      <div>
        <span class="info">自评掌握度:</span>
        ${[0,1,2,3].map(s => `<button class="self-rate" data-s="${s}" title="${['完全不会','部分会','基本会','完全掌握'][s]}">${'★'.repeat(s) || '☆'}</button>`).join('')}
      </div>
    </div>`;
  currentPick = '';
  $('#shortAns').addEventListener('input', e => { currentPick = e.target.value; });
  $$('.self-rate').forEach(b => b.addEventListener('click', () => {
    $$('.self-rate').forEach(x => x.classList.remove('warn'));
    b.classList.add('warn');
    currentPick = { text: $('#shortAns').value, selfRate: Number(b.dataset.s) };
  }));
  const prev = state.perQuestion[current.id]?.selfRate;
  if (prev != null) {
    const b = $$('.self-rate').find(x => Number(x.dataset.s) === prev);
    b && b.classList.add('warn');
  }
}

function renderComp(body) {
  body.innerHTML = `
    <div class="parts-list">
      ${current.parts.map((p, i) => `
        <div class="part" data-pi="${i}">
          <h4>${escapeHtml(p.no)}<span class="part-score">${p.score} 分</span></h4>
          <div class="part-stem">${escapeHtml(p.stem)}</div>
          <textarea data-pi="${i}" placeholder="本小题作答..."></textarea>
        </div>`).join('')}
    </div>
    <div class="action-row" style="border:0; padding-top:8px; margin-top:8px;">
      <span class="info">总体自评:</span>
      ${[0,1,2,3].map(s => `<button class="self-rate" data-s="${s}">${'★'.repeat(s) || '☆'}</button>`).join('')}
    </div>`;
  currentPick = current.parts.map(() => '');
  $$('.part textarea').forEach(ta => {
    ta.addEventListener('input', e => {
      currentPick[Number(e.target.dataset.pi)] = e.target.value;
    });
  });
  $$('.self-rate').forEach(b => b.addEventListener('click', () => {
    $$('.self-rate').forEach(x => x.classList.remove('warn'));
    b.classList.add('warn');
    currentPick.selfRate = Number(b.dataset.s);
  }));
}

/* 排序题 - HTML5 拖拽 + 上下箭头按钮兜底 */
function renderSort(body) {
  currentPick = shuffle(current.sortItems.map(it => it.k));
  body.innerHTML = `
    <div class="note-box">💡 拖拽或用 ↑↓ 按钮调整顺序,完成后提交</div>
    <div class="sort-list" id="sortList">
      ${currentPick.map((k, i) => {
        const it = current.sortItems.find(x => x.k === k);
        return `<div class="sort-item" draggable="true" data-k="${k}">
          <span class="drag-handle">⋮⋮</span>
          <span class="seq">${i+1}</span>
          <span>${escapeHtml(it.t)}</span>
          <div class="updown">
            <button class="tiny ghost up">↑</button>
            <button class="tiny ghost dn">↓</button>
          </div>
        </div>`;
      }).join('')}
    </div>`;
  bindSortEvents();
}

function bindSortEvents() {
  const list = $('#sortList');
  let dragEl = null;
  $$('.sort-item', list).forEach(item => {
    item.addEventListener('dragstart', e => {
      dragEl = item;
      item.classList.add('dragging');
      e.dataTransfer.effectAllowed = 'move';
    });
    item.addEventListener('dragend', () => {
      item.classList.remove('dragging');
      $$('.sort-item', list).forEach(x => x.classList.remove('drag-over'));
    });
    item.addEventListener('dragover', e => {
      e.preventDefault();
      $$('.sort-item', list).forEach(x => x.classList.remove('drag-over'));
      item.classList.add('drag-over');
    });
    item.addEventListener('drop', e => {
      e.preventDefault();
      if (!dragEl || dragEl === item) return;
      const rect = item.getBoundingClientRect();
      const after = (e.clientY - rect.top) > rect.height / 2;
      list.insertBefore(dragEl, after ? item.nextSibling : item);
      reorderSort();
    });
    item.querySelector('.up').addEventListener('click', () => {
      if (item.previousElementSibling) list.insertBefore(item, item.previousElementSibling);
      reorderSort();
    });
    item.querySelector('.dn').addEventListener('click', () => {
      if (item.nextElementSibling) list.insertBefore(item, item.nextElementSibling.nextSibling);
      reorderSort();
    });
  });
}

function reorderSort() {
  const list = $('#sortList');
  currentPick = $$('.sort-item', list).map(x => x.dataset.k);
  $$('.seq', list).forEach((s, i) => s.textContent = i + 1);
}

/* 连线题 - 点击选择配对(桌面/移动都友好) */
function renderMatch(body) {
  currentPick = {}; // left -> right
  const lefts = current.matchPairs.map(p => p.left);
  const rights = shuffle(current.matchPairs.map(p => p.right));
  body.innerHTML = `
    <div class="note-box">💡 先点左边一项,再点右边一项,即可配对。再次点击已选项可取消</div>
    <div class="match-wrap">
      <div class="match-col" id="matchLeft">
        ${lefts.map(l => `<div class="match-cell" data-side="L" data-v="${escapeHtml(l)}"><span>${escapeHtml(l)}</span><span class="badge">—</span></div>`).join('')}
      </div>
      <div class="match-lines" id="matchLines"></div>
      <div class="match-col" id="matchRight">
        ${rights.map(r => `<div class="match-cell" data-side="R" data-v="${escapeHtml(r)}"><span>${escapeHtml(r)}</span><span class="badge">—</span></div>`).join('')}
      </div>
    </div>
    <div class="match-status" id="matchStatus">已配对 0 / ${current.matchPairs.length}</div>`;
  bindMatchEvents();
}

function bindMatchEvents() {
  let pending = null; // 当前待配左侧
  function updateStatus() {
    const n = Object.keys(currentPick).length;
    $('#matchStatus').textContent = `已配对 ${n} / ${current.matchPairs.length}` + (n === current.matchPairs.length ? ' (可提交)' : '');
    $$('#matchLeft .match-cell').forEach(el => {
      const v = el.dataset.v;
      if (currentPick[v]) el.classList.add('matched');
      else el.classList.remove('matched');
      const b = el.querySelector('.badge');
      b.textContent = currentPick[v] || '—';
    });
    $$('#matchRight .match-cell').forEach(el => {
      const v = el.dataset.v;
      const matchedLeft = Object.keys(currentPick).find(k => currentPick[k] === v);
      if (matchedLeft) el.classList.add('matched');
      else el.classList.remove('matched');
      const b = el.querySelector('.badge');
      b.textContent = matchedLeft ? '✓' : '—';
    });
  }
  $$('.match-cell').forEach(el => {
    el.addEventListener('click', () => {
      if (el.classList.contains('matched')) {
        // 取消
        if (el.dataset.side === 'L') {
          const rightVal = currentPick[el.dataset.v];
          delete currentPick[el.dataset.v];
          // 也要取消右侧的 matched 状态
        } else {
          const leftVal = Object.keys(currentPick).find(k => currentPick[k] === el.dataset.v);
          if (leftVal) delete currentPick[leftVal];
        }
        updateStatus();
        return;
      }
      el.classList.add('sel');
      if (el.dataset.side === 'L') {
        if (pending && pending !== el) pending.classList.remove('sel');
        pending = el;
      } else if (pending) {
        // 配对
        currentPick[pending.dataset.v] = el.dataset.v;
        pending.classList.remove('sel');
        pending = null;
        updateStatus();
      }
    });
  });
  updateStatus();
}

/* --------------------------------------------------------------------------
   10. 判题
   -------------------------------------------------------------------------- */
function gradeFor(q, pick) {
  if (q.type === 'single') {
    if (!pick) return 0;
    return setEq([pick], q.answer) ? 3 : 0;
  }
  if (q.type === 'multi') {
    if (!Array.isArray(pick) || !pick.length) return 0;
    const correctSet = new Set(q.answer);
    const pickSet = new Set(pick);
    const hit = [...pickSet].filter(x => correctSet.has(x)).length;
    const miss = [...pickSet].filter(x => !correctSet.has(x)).length;
    if (hit === correctSet.size && miss === 0) return 3;
    if (hit > 0) return 1;
    return 0;
  }
  if (q.type === 'tf') {
    return pick === q.answer ? 3 : 0;
  }
  if (q.type === 'fill') {
    if (!Array.isArray(pick)) return 0;
    let ok = 0;
    q.blanks.forEach((b, i) => {
      if (b.ans.some(a => norm(a) === norm(pick[i] || ''))) ok++;
    });
    if (ok === q.blanks.length) return 3;
    if (ok > 0) return 1;
    return 0;
  }
  if (q.type === 'sort') {
    if (!Array.isArray(pick)) return 0;
    if (arrEq(pick, q.sortKey)) return 3;
    return 1;  // 排错也给 1 分(SRS 重学)
  }
  if (q.type === 'match') {
    const pickSet = currentPick || {};
    const expected = {};
    q.matchPairs.forEach(p => expected[p.left] = p.right);
    let ok = 0;
    Object.entries(pickSet).forEach(([l, r]) => { if (expected[l] === r) ok++; });
    if (ok === q.matchPairs.length) return 3;
    if (ok > 0) return 1;
    return 0;
  }
  if (q.type === 'short') {
    if (typeof pick === 'object' && pick !== null) {
      if (pick.selfRate != null) return pick.selfRate;
      if (pick.text?.trim()) return 1;
    }
    if (String(pick || '').trim()) return 1;
    return 0;
  }
  if (q.type === 'comp') {
    if (typeof pick === 'object' && pick !== null) {
      if (pick.selfRate != null) return pick.selfRate;
      if (Array.isArray(pick) && pick.some(x => x && x.trim())) return 1;
    }
    return 0;
  }
  return 0;
}

function recordAttempt(q, pick, grade) {
  const r = getCard(q.id);
  r.attempts++;
  r.lastTs = Date.now();
  const correct = grade >= 2;
  if (correct) r.correct++; else r.wrong++;
  // SRS
  r.srs = Object.assign({}, r.srs || DEFAULT_SRS(), srsUpdate(r.srs || DEFAULT_SRS(), grade));
  // 类型特化字段
  if (q.type === 'short' && pick && typeof pick === 'object') {
    r.selfRate = pick.selfRate != null ? pick.selfRate : r.selfRate;
    r.lastText = pick.text || '';
  }
  if (q.type === 'comp' && pick && typeof pick === 'object') {
    r.selfRate = pick.selfRate != null ? pick.selfRate : r.selfRate;
    r.lastParts = pick;
  }
  sessionCorrect += correct ? 1 : 0;
  sessionDone++;
  saveState();
}

function paintResult(grade) {
  const q = current;
  const correct = grade >= 2;
  if (q.type === 'single') {
    const ans = q.answer;
    $$('#optList label').forEach(lab => {
      const k = lab.dataset.k;
      if (ans.includes(k)) lab.classList.add('correct');
      if (k === currentPick && !ans.includes(k)) lab.classList.add('wrong-sel');
    });
  } else if (q.type === 'multi') {
    const ans = new Set(q.answer);
    $$('#optList label').forEach(lab => {
      const k = lab.dataset.k;
      const picked = currentPick.includes(k);
      if (ans.has(k)) lab.classList.add('correct');
      else if (picked) lab.classList.add('wrong-sel');
    });
  } else if (q.type === 'tf') {
    $$('.tf-row button').forEach(b => {
      if (b.dataset.pick === q.answer) b.classList.add('correct');
      if (b.dataset.pick === currentPick && currentPick !== q.answer) b.classList.add('wrong-sel');
    });
  } else if (q.type === 'fill') {
    q.blanks.forEach((b, i) => {
      const inp = $(`.fill-row input[data-bi="${i}"]`);
      const ok = b.ans.some(a => norm(a) === norm(currentPick[i] || ''));
      inp.classList.add(ok ? 'ok' : 'bad');
    });
  } else if (q.type === 'sort') {
    $$('.sort-item').forEach((el, i) => {
      const k = el.dataset.k;
      const want = q.sortKey[i];
      el.classList.add(k === want ? 'correct-pos' : 'wrong-pos');
    });
  } else if (q.type === 'match') {
    const expected = {};
    q.matchPairs.forEach(p => expected[p.left] = p.right);
    $$('#matchLeft .match-cell').forEach(el => {
      const l = el.dataset.v;
      const r = currentPick[l];
      if (r) el.classList.add(expected[l] === r ? 'matched' : 'matched-wrong');
    });
  }
}

/* --------------------------------------------------------------------------
   11. 显示答案
   -------------------------------------------------------------------------- */
function showAnswer() {
  if (!current) return;
  showAnswerNow = true;
  paintAnswerBox();
  refreshActionButtons();
}
function paintAnswerBox() {
  const box = $('#answerBox');
  if (!box) return;
  const q = current;
  let html = '';
  if (q.type === 'single' || q.type === 'tf') {
    const ansText = q.type === 'tf' ? (q.answer === 'T' ? '✓ 对' : '✗ 错') : q.answer.join('、');
    html = `<div class="answer-box">
      <h4>答案：${ansText}</h4>
      ${q.explain ? `<div>${escapeHtml(q.explain)}</div>` : ''}
    </div>`;
  } else if (q.type === 'multi') {
    html = `<div class="answer-box">
      <h4>答案：${q.answer.join('、')}</h4>
      ${q.explain ? `<div>${escapeHtml(q.explain)}</div>` : ''}
    </div>`;
  } else if (q.type === 'fill') {
    html = `<div class="answer-box">
      <h4>参考答案：</h4>
      ${q.blanks.map((b, i) => `<div>第 ${i + 1} 空：<strong>${b.ans.map(escapeHtml).join(' / ')}</strong></div>`).join('')}
      ${q.explain ? `<div style="margin-top:6px;">${escapeHtml(q.explain)}</div>` : ''}
    </div>`;
  } else if (q.type === 'sort') {
    html = `<div class="answer-box">
      <h4>正确顺序：</h4>
      <div>${q.sortKey.map((k, i) => `${i+1}. ${escapeHtml(q.sortItems.find(x => x.k === k).t)}`).join('<br>')}</div>
      ${q.explain ? `<div style="margin-top:6px;">${escapeHtml(q.explain)}</div>` : ''}
    </div>`;
  } else if (q.type === 'match') {
    html = `<div class="answer-box">
      <h4>正确配对：</h4>
      ${q.matchPairs.map(p => `<div>${escapeHtml(p.left)} → <strong>${escapeHtml(p.right)}</strong></div>`).join('')}
      ${q.explain ? `<div style="margin-top:6px;">${escapeHtml(q.explain)}</div>` : ''}
    </div>`;
  } else if (q.type === 'short') {
    html = `
      <div class="answer-box">
        <h4>参考答案：</h4>
        <div>${escapeHtml(q.refAnswer)}</div>
      </div>
      <div class="answer-box">
        <h4>得分点（${q.points.reduce((s,p) => s + p.score, 0)} 分）：</h4>
        <ul class="points-list">
          ${q.points.map(p => `<li><span class="sc">${p.score}</span><strong>${escapeHtml(p.key)}：</strong>${escapeHtml(p.text)}</li>`).join('')}
        </ul>
      </div>
      ${q.explain ? `<div class="note-box">💡 ${escapeHtml(q.explain)}</div>` : ''}`;
  } else if (q.type === 'comp') {
    html = q.parts.map((p, i) => `
      <div class="answer-box">
        <h4>${escapeHtml(p.no)} 参考答案（${p.score} 分）</h4>
        <div>${escapeHtml(p.refAnswer)}</div>
        <ul class="points-list">
          ${p.points.map(pp => `<li><span class="sc">${pp.score}</span><strong>${escapeHtml(pp.key)}：</strong>${escapeHtml(pp.text)}</li>`).join('')}
        </ul>
      </div>`).join('');
  }
  // SRS 提示
  const card = state.perQuestion[q.id];
  if (card && card.srs && (card.attempts || 0) > 0) {
    const due = fmtDay(card.srs.due);
    html += `<div class="note-box">📅 SRS：间隔 ${card.srs.interval} 天，下次复习：${due}（ef=${card.srs.ef}）</div>`;
  }
  box.innerHTML = html;
}

/* --------------------------------------------------------------------------
   12. 事件绑定（单题内）
   -------------------------------------------------------------------------- */
function bindCardEvents() {
  $('#submitBtn').addEventListener('click', submitAnswer);
  $('#userNote').addEventListener('input', e => {
    const r = getCard(current.id);
    r.userNote = e.target.value;
    saveState();
  });
  $('#clearPick').addEventListener('click', () => {
    currentPick = current.type === 'fill' ? current.blanks.map(()=>'')
              : current.type === 'sort' ? shuffle(current.sortItems.map(it => it.k))
              : current.type === 'match' ? {}
              : null;
    if (current.type === 'single' || current.type === 'multi') {
      $$('#optList label').forEach(x => { x.classList.remove('sel','correct','wrong-sel'); x.querySelector('input').checked = false; });
    }
    if (current.type === 'tf') {
      $$('.tf-row button').forEach(x => x.classList.remove('sel','correct','wrong-sel'));
    }
    if (current.type === 'fill') {
      $$('.fill-row input').forEach(x => { x.value = ''; x.classList.remove('ok','bad'); });
    }
    if (current.type === 'short') { $('#shortAns').value = ''; }
    if (current.type === 'comp') { $$('.part textarea').forEach(x => x.value = ''); }
    if (current.type === 'sort') {
      const list = $('#sortList');
      const cells = $$('.sort-item', list);
      cells.forEach(c => { c.classList.remove('correct-pos', 'wrong-pos'); });
    }
    if (current.type === 'match') {
      $$('.match-cell').forEach(c => { c.classList.remove('matched','matched-wrong','sel'); c.querySelector('.badge').textContent = '—'; });
      $('#matchStatus').textContent = `已配对 0 / ${current.matchPairs.length}`;
    }
  });
}

function submitAnswer() {
  if (!current) return;
  const q = current;
  const grade = gradeFor(q, currentPick);
  // 模拟考试
  if (state.exam.active) {
    state.exam.answers[q.id] = { pick: currentPick, grade, ts: Date.now() };
    saveState();
    showAnswer();
    toast(grade >= 2 ? '✓ 答对' : (q.type === 'short' || q.type === 'comp') ? '✓ 已记录' : '✗ 答错');
    return;
  }
  // 必须有作答
  const empty =
    (q.type === 'single' && !currentPick) ||
    (q.type === 'tf' && !currentPick) ||
    (q.type === 'fill' && (currentPick || []).every(x => !x || !x.trim())) ||
    (q.type === 'short' && (typeof currentPick === 'string' ? !currentPick.trim() : !currentPick?.text?.trim())) ||
    (q.type === 'multi' && (!Array.isArray(currentPick) || !currentPick.length));
  if (empty) { toast('请先作答'); return; }
  recordAttempt(q, currentPick, grade);
  paintResult(grade);
  showAnswer();
  refreshNav();
  refreshProgress();
  refreshDuePill();
  toast(grade === 3 ? '✓ 简单' : grade === 2 ? '✓ 良好' : grade === 1 ? '◐ 部分对' : '✗ 重来');
}

/* --------------------------------------------------------------------------
   13. 翻页
   -------------------------------------------------------------------------- */
function go(delta) {
  if (!currentList.length) return;
  const next = currentIdx + delta;
  if (next < 0 || next >= currentList.length) return;
  currentIdx = next;
  renderCurrent();
  refreshNav();
  refreshProgress();
}
$('#prevBtn').addEventListener('click', () => go(-1));
$('#nextBtn').addEventListener('click', () => go(1));
$('#showAnsBtn').addEventListener('click', () => {
  if (showAnswerNow) {
    showAnswerNow = false;
    const box = $('#answerBox'); if (box) box.innerHTML = '';
    refreshActionButtons();
  } else showAnswer();
});
$('#favBtn').addEventListener('click', () => {
  if (!current) return;
  const r = getCard(current.id);
  r.fav = !r.fav; saveState(); refreshActionButtons(); refreshNav();
  toast(r.fav ? '已加入收藏' : '已取消收藏');
});
$('#reviewBtn').addEventListener('click', () => {
  if (!current) return;
  const r = getCard(current.id);
  r.review = !r.review; saveState(); refreshActionButtons(); refreshNav();
  toast(r.review ? '已标记待复习' : '已取消标记');
});

/* --------------------------------------------------------------------------
   14. 模式按钮 / 筛选 / 搜索 / 今日复习
   -------------------------------------------------------------------------- */
$$('#modeGrid .mode-btn').forEach(b => b.addEventListener('click', () => setMode(b.dataset.mode)));
$('#duePill').addEventListener('click', () => {
  if (dueCount() === 0) { toast('今日暂无 SRS 待复习题'); return; }
  setMode('srs');
});

function fillFilterOptions() {
  const TLABEL = activeTypeLabel();
  const CATS = activeCategories();
  const ts = $('#filterType');
  ts.innerHTML = '<option value="">全部题型</option>';
  TYPE_ORDER.forEach(k => {
    if (!TLABEL[k]) return;
    const o = document.createElement('option'); o.value = k; o.textContent = TLABEL[k]; ts.appendChild(o);
  });
  const cs = $('#filterCat');
  cs.innerHTML = '<option value="">全部知识点</option>';
  Object.entries(CATS).forEach(([k, v]) => {
    const o = document.createElement('option'); o.value = k; o.textContent = v; cs.appendChild(o);
  });
  ts.value = state.session.type || '';
  cs.value = state.session.category || '';
  $('#searchInput').value = state.session.search || '';
}
$('#filterType').addEventListener('change', applyFilter);
$('#filterCat').addEventListener('change', () => {
  if (state.session.category) state.session.mode = 'category';
  applyFilter();
});
let searchTimer = null;
$('#searchInput').addEventListener('input', () => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(applyFilter, 200);
});

/* --------------------------------------------------------------------------
   15. 模拟考试
   -------------------------------------------------------------------------- */
let examTimerId = null;
function startExamTimer() {
  stopExamTimer();
  examTimerId = setInterval(() => {
    if (!state.exam.active) { stopExamTimer(); return; }
    const left = state.exam.timeLimit - Math.floor((Date.now() - state.exam.startTs) / 1000);
    $('#timer').textContent = fmtTime(left);
    if (left <= 0) { stopExamTimer(); finishExam(true); }
  }, 500);
}
function stopExamTimer() { if (examTimerId) { clearInterval(examTimerId); examTimerId = null; } }

function finishExam(timeout) {
  const queue = state.exam.queue.map(id => activeQuestions().find(q => q.id === id)).filter(Boolean);
  let correct = 0, wrong = 0, blank = 0;
  const detail = [];
  queue.forEach(q => {
    const ans = state.exam.answers[q.id];
    if (!ans) blank++;
    else if ((ans.grade ?? 0) >= 2) correct++;
    else wrong++;
    detail.push({ q, ans });
  });
  // 写入统计与 SRS
  detail.forEach(({q, ans}) => {
    if (!ans) return;
    const r = getCard(q.id);
    r.attempts++; r.lastTs = Date.now();
    if ((ans.grade ?? 0) >= 2) r.correct++; else r.wrong++;
    if (ans.grade != null) r.srs = Object.assign({}, r.srs, srsUpdate(r.srs || DEFAULT_SRS(), ans.grade));
  });
  const total = queue.length;
  const score = Math.round(correct * 100 / Math.max(1, total));
  state.exam.active = false;
  // 记录到历史
  state.sessions.push({
    ts: Date.now(), total, correct, wrong, blank, score, mode: 'exam'
  });
  saveState();
  const TLABEL = activeTypeLabel();
  const CATS = activeCategories();
  const html = `
    <div class="stat-grid" style="margin-bottom:14px;">
      <div class="stat-cell"><div class="v" style="color:var(--green)">${correct}</div><div class="l">答对</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--red)">${wrong}</div><div class="l">答错</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--muted)">${blank}</div><div class="l">未答</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--accent)">${score}</div><div class="l">得分（百分制）</div></div>
    </div>
    <p>${timeout ? '⏰ 考试时间到，已自动交卷。' : '已交卷。'} 可点击下方"按题号复盘"逐题回顾。</p>
    <h3 style="margin-top:14px;">逐题结果</h3>
    <table>
      <thead><tr><th>原号</th><th>题型</th><th>结果</th><th>你的答案</th><th>正确答案</th></tr></thead>
      <tbody>
        ${detail.map(({q, ans}) => {
          const ok = (ans?.grade ?? 0) >= 2;
          return `<tr>
            <td>第 ${q.no} 题 · q${q.id.slice(1)}</td>
            <td>${TLABEL[q.type] || q.type}</td>
            <td>${ans ? (ok ? '<span style="color:var(--green)">✓</span>' : '<span style="color:var(--red)">✗</span>') : '<span style="color:var(--muted)">—</span>'}</td>
            <td>${formatPickForTable(q, ans?.pick)}</td>
            <td>${formatAnswerForTable(q)}</td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>`;
  openModal({
    title: '📝 模拟考试结果',
    body: html,
    actions: [
      { label: '按题号复盘', primary: true, onClick: () => { closeModal(); state.session.mode='sequential'; startSession(); } },
      { label: '再做一次', onClick: () => { closeModal(); setMode('exam'); } }
    ]
  });
}
function formatPickForTable(q, pick) {
  if (pick == null) return '—';
  if (q.type === 'single') return pick;
  if (q.type === 'multi') return Array.isArray(pick) ? pick.join('、') : '—';
  if (q.type === 'tf') return pick === 'T' ? '对' : '错';
  if (q.type === 'fill') return (pick || []).join(' / ') || '—';
  if (q.type === 'sort') return Array.isArray(pick) ? pick.join('→') : '—';
  if (q.type === 'match') {
    if (!pick || typeof pick !== 'object') return '—';
    return Object.keys(pick).length + ' 对连线';
  }
  if (q.type === 'short') return (pick && pick.text) ? escapeHtml(pick.text.slice(0,30)) : '—';
  if (q.type === 'comp') return (pick && Array.isArray(pick)) ? pick.filter(Boolean).length + ' 部分作答' : '—';
  return '—';
}
function formatAnswerForTable(q) {
  if (q.type === 'single' || q.type === 'multi') return (q.answer || []).join('、');
  if (q.type === 'tf') return q.answer === 'T' ? '对' : '错';
  if (q.type === 'fill') return q.blanks.map(b => b.ans[0]).join(' / ');
  if (q.type === 'sort') return q.sortKey.join('→');
  if (q.type === 'match') return q.matchPairs.map(p => `${p.left}=${p.right}`).join(', ');
  if (q.type === 'short') return '见解析';
  if (q.type === 'comp') return '见解析';
  return '—';
}

/* --------------------------------------------------------------------------
   16. 模态框
   -------------------------------------------------------------------------- */
function openModal({ title, body, actions }) {
  $('#modalTitle').textContent = title;
  $('#modalBody').innerHTML = body;
  const footer = $('#modalFooter');
  footer.innerHTML = '';
  (actions || [{ label:'关闭', onClick: closeModal }]).forEach(a => {
    const b = document.createElement('button');
    b.className = a.primary ? 'primary' : '';
    b.textContent = a.label;
    b.addEventListener('click', a.onClick || closeModal);
    footer.appendChild(b);
  });
  $('#mask').classList.add('open');
}
function closeModal() { $('#mask').classList.remove('open'); }
$('#mask').addEventListener('click', e => { if (e.target.id === 'mask') closeModal(); });
$$('[data-close]').forEach(b => b.addEventListener('click', closeModal));
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });

/* --------------------------------------------------------------------------
   17. 可视化统计 (SVG 自绘)
   -------------------------------------------------------------------------- */
function renderRadar(byCat) {
  const entries = Object.entries(byCat);
  if (!entries.length) return '<p style="color:var(--muted)">暂无数据</p>';
  const max = 100;
  const cx = 200, cy = 170, R = 130;
  const N = entries.length;
  const angle = i => -Math.PI / 2 + i * 2 * Math.PI / N;
  const pt = (i, r) => [cx + Math.cos(angle(i)) * r, cy + Math.sin(angle(i)) * r];
  // 网格圈 (25/50/75/100)
  let grid = '';
  [0.25, 0.5, 0.75, 1].forEach((p, idx) => {
    const pts = entries.map((_, i) => pt(i, R * p).join(',')).join(' ');
    grid += `<polygon points="${pts}" fill="none" stroke="var(--line)" stroke-width="1" opacity="${0.5 - idx*0.1}"/>`;
  });
  // 轴线
  let axes = '';
  entries.forEach((_, i) => {
    const [x, y] = pt(i, R);
    axes += `<line x1="${cx}" y1="${cy}" x2="${x}" y2="${y}" stroke="var(--line)" stroke-width="1" opacity="0.5"/>`;
  });
  // 数据多边形
  const dataPts = entries.map(([k, v], i) => {
    const a = v.attempts ? v.correct / v.attempts : 0;
    return pt(i, R * a).join(',');
  }).join(' ');
  // 平均参考线
  const allAcc = entries.reduce((s, [k, v]) => s + (v.attempts ? v.correct / v.attempts : 0), 0) / N;
  const refPts = entries.map((_, i) => pt(i, R * allAcc).join(',')).join(' ');
  // 标签
  let labels = '';
  entries.forEach(([k, v], i) => {
    const [x, y] = pt(i, R + 22);
    const acc = v.attempts ? Math.round(v.correct * 100 / v.attempts) : 0;
    labels += `<text x="${x}" y="${y}" text-anchor="middle" font-size="11" fill="var(--ink)">${escapeHtml(activeCategories()[k] || k)}</text>`;
    labels += `<text x="${x}" y="${y + 13}" text-anchor="middle" font-size="10" fill="var(--muted)">${acc}% (${v.attempts})</text>`;
  });
  return `<svg viewBox="0 0 400 360" width="400" height="360">
    ${grid}${axes}
    <polygon points="${refPts}" fill="none" stroke="var(--muted)" stroke-width="1" stroke-dasharray="3 3" opacity="0.5"/>
    <polygon points="${dataPts}" fill="var(--accent)" fill-opacity="0.18" stroke="var(--accent)" stroke-width="2"/>
    ${entries.map(([k, v], i) => {
      const a = v.attempts ? v.correct / v.attempts : 0;
      const [x, y] = pt(i, R * a);
      return `<circle cx="${x}" cy="${y}" r="3" fill="var(--accent)"/>`;
    }).join('')}
    ${labels}
    <text x="200" y="20" text-anchor="middle" font-size="12" fill="var(--muted)">虚线=平均 ${Math.round(allAcc*100)}%</text>
  </svg>`;
}

function renderTrend(byDay) {
  // byDay: [{date:'2026-07-02', attempts, correct}]
  const days = [];
  for (let i = 13; i >= 0; i--) {
    const d = new Date(); d.setHours(0,0,0,0); d.setDate(d.getDate() - i);
    const key = d.toISOString().slice(0, 10);
    const found = byDay.find(b => b.date === key);
    days.push({ date: key, attempts: found?.attempts || 0, correct: found?.correct || 0 });
  }
  const W = 560, H = 180, padL = 30, padR = 10, padT = 10, padB = 24;
  const innerW = W - padL - padR, innerH = H - padT - padB;
  const maxA = Math.max(1, ...days.map(d => d.attempts));
  const barW = innerW / days.length * 0.6;
  const xAt = i => padL + (i + 0.5) * (innerW / days.length);
  const yAt = v => padT + innerH - (v / maxA) * innerH;
  let bars = '', line = '', pts = [], labels = '';
  days.forEach((d, i) => {
    const x = xAt(i);
    const y = yAt(d.attempts);
    const h = innerH - (y - padT);
    const acc = d.attempts ? Math.round(d.correct * 100 / d.attempts) : 0;
    const color = acc >= 80 ? 'var(--green)' : acc >= 60 ? 'var(--accent)' : acc >= 40 ? 'var(--orange)' : 'var(--red)';
    if (d.attempts > 0) {
      bars += `<rect x="${x - barW/2}" y="${y}" width="${barW}" height="${h}" fill="${color}" opacity="0.85"><title>${d.date}: ${d.attempts} 题, ${acc}%</title></rect>`;
      pts.push([x, y]);
    }
    if (i % 2 === 0 || i === days.length - 1) {
      labels += `<text x="${x}" y="${H - 6}" text-anchor="middle" font-size="9" fill="var(--muted)">${d.date.slice(5)}</text>`;
    }
  });
  // 趋势线
  if (pts.length >= 2) {
    line = `<polyline points="${pts.map(p => p.join(',')).join(' ')}" fill="none" stroke="var(--accent)" stroke-width="2" opacity="0.7"/>`;
    pts.forEach(([x, y]) => {
      line += `<circle cx="${x}" cy="${y}" r="2.5" fill="var(--accent)"/>`;
    });
  }
  // Y 轴
  const yMarks = [0, 0.5, 1].map(p => {
    const y = yAt(maxA * p);
    return `<line x1="${padL}" y1="${y}" x2="${W - padR}" y2="${y}" stroke="var(--line)" stroke-width="1" opacity="0.5"/>
            <text x="${padL - 4}" y="${y + 3}" text-anchor="end" font-size="9" fill="var(--muted)">${Math.round(maxA * p)}</text>`;
  }).join('');
  return `<svg viewBox="0 0 ${W} ${H}" width="100%" height="${H}">
    ${yMarks}${bars}${line}${labels}
    <text x="${W/2}" y="14" text-anchor="middle" font-size="11" fill="var(--muted)">最近 14 天 · 柱=答题数 / 折线=趋势</text>
  </svg>`;
}

function renderTypeBars(byType) {
  const entries = Object.entries(byType);
  const W = 560, padL = 80, padR = 60, barH = 26, gap = 8;
  const totalH = entries.length * (barH + gap) + 20;
  let bars = '';
  const max = Math.max(1, ...entries.map(([k,v]) => v.attempts));
  entries.forEach(([k, v], i) => {
    const y = 10 + i * (barH + gap);
    const w = ((W - padL - padR) * v.attempts) / max;
    const acc = v.attempts ? Math.round(v.correct * 100 / v.attempts) : 0;
    const color = acc >= 80 ? 'var(--green)' : acc >= 60 ? 'var(--accent)' : acc >= 40 ? 'var(--orange)' : 'var(--red)';
    bars += `<text x="${padL - 6}" y="${y + barH/2 + 4}" text-anchor="end" font-size="12" fill="var(--ink)">${escapeHtml(activeTypeLabel()[k] || k)}</text>`;
    bars += `<rect x="${padL}" y="${y}" width="${w}" height="${barH}" fill="${color}" rx="3"><title>${v.attempts} 题 · ${acc}%</title></rect>`;
    bars += `<text x="${padL + w + 6}" y="${y + barH/2 + 4}" font-size="11" fill="var(--ink)">${v.attempts} 题 · ${acc}%</text>`;
  });
  return `<svg viewBox="0 0 ${W} ${totalH}" width="100%" height="${totalH}">${bars}</svg>`;
}

function renderWeakList(weakList) {
  if (!weakList.length) return '<p style="color:var(--green)">🎉 暂无明显薄弱点</p>';
  return weakList.map(w => `
    <div class="weak-item">
      <div class="wi-info">
        <strong>${escapeHtml(w.title)}</strong>
        <div style="font-size:11px;color:var(--muted)">${w.attempts} 题 · 正确 ${w.correct}</div>
      </div>
      <div class="wi-score">${w.acc}%</div>
      <button class="tiny primary" data-cat="${w.key}">📍 去练</button>
    </div>
  `).join('');
}

/* --------------------------------------------------------------------------
   18. 统计弹窗
   -------------------------------------------------------------------------- */
$('#openStats').addEventListener('click', () => {
  const QS = activeQuestions();
  const CATS = activeCategories();
  const TLABEL = activeTypeLabel();
  let attempts = 0, correct = 0, wrong = 0, favs = 0, reviews = 0, dueN = 0;
  const byType = {}, byCat = {}, byDay = [];
  const dayMap = new Map();
  QS.forEach(q => {
    const r = state.perQuestion[q.id] || {};
    attempts += (r.correct || 0) + (r.wrong || 0);
    correct += r.correct || 0;
    wrong   += r.wrong || 0;
    if (r.fav) favs++;
    if (r.review) reviews++;
    if (r.srs && r.srs.due && r.srs.due <= Date.now() && (r.attempts || 0) > 0) dueN++;
    byType[q.type] = byType[q.type] || { c: 0, w: 0, t: 0, attempts: 0 };
    byType[q.type].c += r.correct || 0;
    byType[q.type].w += r.wrong || 0;
    byType[q.type].t++;
    byType[q.type].attempts += (r.correct || 0) + (r.wrong || 0);
    byCat[q.cat] = byCat[q.cat] || { c: 0, w: 0, t: 0, attempts: 0 };
    byCat[q.cat].c += r.correct || 0;
    byCat[q.cat].w += r.wrong || 0;
    byCat[q.cat].t++;
    byCat[q.cat].attempts += (r.correct || 0) + (r.wrong || 0);
    if (r.lastTs) {
      const day = new Date(r.lastTs).toISOString().slice(0, 10);
      const e = dayMap.get(day) || { date: day, attempts: 0, correct: 0 };
      e.attempts += (r.correct || 0) + (r.wrong || 0);
      e.correct += r.correct || 0;
      dayMap.set(day, e);
    }
  });
  dayMap.forEach(v => byDay.push(v));
  const acc = attempts ? Math.round(correct * 100 / attempts) : 0;
  const html = `
    <div class="stat-grid">
      <div class="stat-cell"><div class="v">${QS.length}</div><div class="l">题库总题数</div></div>
      <div class="stat-cell"><div class="v">${attempts}</div><div class="l">累计作答</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--green)">${correct}</div><div class="l">答对</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--red)">${wrong}</div><div class="l">答错</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--accent)">${acc}%</div><div class="l">整体正确率</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--orange)">${dueN}</div><div class="l">SRS 待复习</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--amber)">${favs}</div><div class="l">收藏</div></div>
      <div class="stat-cell"><div class="v" style="color:var(--orange)">${reviews}</div><div class="l">待复习标记</div></div>
    </div>
    <h3 style="margin-top:14px;">📈 14 天趋势</h3>
    ${renderTrend(byDay)}
    <h3 style="margin-top:14px;">🎯 知识点雷达</h3>
    ${renderRadar(byCat)}
    <h3 style="margin-top:14px;">📊 题型分布</h3>
    ${renderTypeBars(byType)}
  `;
  openModal({ title:'📊 学习统计', body: html });
});

/* 薄弱点 */
$('#openWeak').addEventListener('click', () => {
  const QS = activeQuestions();
  const CATS = activeCategories();
  const byCat = {};
  QS.forEach(q => {
    const r = state.perQuestion[q.id] || {};
    byCat[q.cat] = byCat[q.cat] || { c: 0, w: 0, attempts: 0 };
    byCat[q.cat].c += r.correct || 0;
    byCat[q.cat].w += r.wrong || 0;
    byCat[q.cat].attempts += (r.correct || 0) + (r.wrong || 0);
  });
  // 排序：(1-正确率) × 题数 × 难度
  const list = Object.entries(byCat)
    .filter(([k, v]) => v.attempts > 0)
    .map(([k, v]) => {
      const acc = v.correct / v.attempts;
      const diffAvg = QS.filter(q => q.cat === k).reduce((s, q) => s + q.diff, 0) / Math.max(1, QS.filter(q => q.cat === k).length);
      return {
        key: k,
        title: CATS[k] || k,
        attempts: v.attempts,
        correct: v.correct,
        acc: Math.round(acc * 100),
        score: (1 - acc) * v.attempts * diffAvg
      };
    })
    .sort((a, b) => b.score - a.score)
    .slice(0, 5);
  const html = `
    <p>按 "(错误率 × 题数 × 难度) 综合评分" 排序前 5。点击「去练」切换到专项突破模式。</p>
    ${renderWeakList(list)}
  `;
  openModal({
    title: '🎯 薄弱知识点 Top 5',
    body: html,
    actions: [{ label:'关闭', onClick: closeModal }]
  });
  // 绑定去练按钮
  $$('.weak-item [data-cat]').forEach(b => b.addEventListener('click', () => {
    const cat = b.dataset.cat;
    closeModal();
    state.session.category = cat;
    state.session.mode = 'category';
    $('#filterCat').value = cat;
    saveState();
    startSession();
  }));
});

$('#openWrongs').addEventListener('click', () => {
  const list = activeQuestions().filter(q => (state.perQuestion[q.id]?.wrong || 0) > 0);
  if (!list.length) { toast('还没有错题 🎉'); return; }
  const CATS = activeCategories();
  const TLABEL = activeTypeLabel();
  const html = `<p>共 <strong>${list.length}</strong> 道错题。</p>
    <table>
      <thead><tr><th>原号</th><th>题型</th><th>知识点</th><th>错</th><th>对</th><th>SRS</th></tr></thead>
      <tbody>
        ${list.map(q => {
          const r = state.perQuestion[q.id];
          return `<tr>
            <td>第 ${q.no} · q${q.id.slice(1)}</td>
            <td>${TLABEL[q.type]}</td>
            <td>${CATS[q.cat]}</td>
            <td>${r.wrong}</td>
            <td>${r.correct || 0}</td>
            <td>${r.srs ? fmtDay(r.srs.due) : '—'}</td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>`;
  openModal({
    title:'❌ 错题本',
    body: html,
    actions: [
      { label:'关闭', onClick: closeModal },
      { label:'开始重练', primary:true, onClick: () => { closeModal(); setMode('wrong'); } }
    ]
  });
});

$('#openFavs').addEventListener('click', () => {
  const list = activeQuestions().filter(q => state.perQuestion[q.id]?.fav);
  if (!list.length) { toast('暂无收藏题'); return; }
  const CATS = activeCategories();
  const TLABEL = activeTypeLabel();
  const html = `<p>共 <strong>${list.length}</strong> 道收藏题。</p>
    <table>
      <thead><tr><th>原号</th><th>题型</th><th>知识点</th><th>难度</th><th>题干预览</th></tr></thead>
      <tbody>
        ${list.map(q => `<tr><td>第 ${q.no} · q${q.id.slice(1)}</td><td>${TLABEL[q.type]}</td><td>${CATS[q.cat]}</td><td>${'★'.repeat(q.diff)}</td><td style="max-width:380px;">${escapeHtml(q.stem.slice(0,60))}${q.stem.length>60?'…':''}</td></tr>`).join('')}
      </tbody>
    </table>`;
  openModal({
    title:'★ 收藏夹',
    body: html,
    actions: [
      { label:'关闭', onClick: closeModal },
      { label:'开始复习', primary:true, onClick: () => { closeModal(); setMode('fav'); } }
    ]
  });
});

/* --------------------------------------------------------------------------
   19. 帮助 / 设置 / 导入
   -------------------------------------------------------------------------- */
$('#openHelp').addEventListener('click', () => {
  const html = `
    <p>本站所有数据保存在浏览器本地（localStorage），不上传任何服务器。可在 Chrome 中"添加到主屏幕"离线使用（PWA）。</p>
    <h3>键盘快捷键</h3>
    <table>
      <tbody>
        <tr><td><span class="kbd">1</span> <span class="kbd">2</span> <span class="kbd">3</span> <span class="kbd">4</span></td><td>选择 A / B / C / D（单选/多选）</td></tr>
        <tr><td><span class="kbd">5</span></td><td>判断题选「对」</td></tr>
        <tr><td><span class="kbd">6</span></td><td>判断题选「错」</td></tr>
        <tr><td><span class="kbd">Enter</span></td><td>提交答案</td></tr>
        <tr><td><span class="kbd">Space</span></td><td>显示 / 隐藏答案</td></tr>
        <tr><td><span class="kbd">→</span> / <span class="kbd">←</span></td><td>下一题 / 上一题</td></tr>
        <tr><td><span class="kbd">F</span> / <span class="kbd">R</span></td><td>收藏 / 待复习</td></tr>
        <tr><td><span class="kbd">Esc</span></td><td>关闭弹窗</td></tr>
      </tbody>
    </table>
    <h3>v2 新特性</h3>
    <ul>
      <li><strong>SRS 间隔重复</strong> · 答对自动延后复习（1d → 3d → 7d → 30d），答错立即重做</li>
      <li><strong>题型扩充</strong> · 新增多选(multi) / 排序(sort) / 连线(match)</li>
      <li><strong>可视化统计</strong> · SVG 自绘雷达图 + 14 天趋势折线 + 题型分布柱状</li>
      <li><strong>薄弱点定位</strong> · 自动按"错误率 × 题数 × 难度"识别前 5 薄弱知识点</li>
      <li><strong>题库导入</strong> · 支持 JSON 模板导入新题库，合并/覆盖/跳过策略</li>
      <li><strong>PWA</strong> · 添加到主屏幕、离线可用</li>
      <li><strong>题号双编号</strong> · 题号网格显示 原号 · qN，与纸质卷对齐</li>
    </ul>
  `;
  openModal({ title:'⌨ 使用说明', body: html });
});

$('#openSettings').addEventListener('click', () => {
  const html = `
    <h3>显示</h3>
    <p>主题：<button id="setTheme">${state.session.theme === 'dark' ? '切换到亮色' : '切换到暗色'}</button>
      　字号：<button id="setFont">当前 ${({sm:'小',md:'中',lg:'大'}[state.session.font] || '中')}</button></p>
    <h3>数据</h3>
    <p>所有学习数据保存在浏览器 localStorage（key = <code>${STORE_KEY}</code>）。</p>
    <p>
      <button id="expBtn">📤 导出 JSON 备份</button>
      <button id="impBtn">📥 导入 JSON 备份</button>
      <button id="clearBtn" class="danger">🗑 清空所有记录</button>
    </p>
    <h3>打印</h3>
    <p>浏览器 <strong>Ctrl/Cmd + P</strong> 即可打印（带答案版）。</p>
  `;
  openModal({ title:'⚙ 设置', body: html, actions: [{ label:'关闭', onClick: closeModal }] });
  setTimeout(() => {
    $('#setTheme').onclick = () => { $('#themeBtn').click(); };
    $('#setFont').onclick  = () => { $('#fontBtn').click(); };
    $('#clearBtn').onclick = () => { closeModal(); resetAll(); };
    $('#expBtn').onclick = exportData;
    $('#impBtn').onclick = importData;
  }, 0);
});

$('#resetAll').addEventListener('click', resetAll);

/* 导入题库 */
$('#openImport').addEventListener('click', () => {
  const html = `
    <p>选择 JSON 文件导入题库。支持的字段：<code>version</code>, <code>categories</code>, <code>typeLabel</code>, <code>questions[]</code>。</p>
    <p>每题至少包含：<code>id</code>, <code>type</code>, <code>cat</code>, <code>stem</code>，以及对应题型的 <code>answer</code> / <code>blanks</code> / <code>parts</code> / <code>sortItems</code>+<code>sortKey</code> / <code>matchPairs</code>。</p>
    <p>
      <button id="impFileBtn" class="primary">📂 选择文件</button>
      <button id="impTplBtn">📄 下载模板</button>
    </p>
    <div id="impResult"></div>
  `;
  openModal({ title:'📥 导入题库', body: html, actions: [{ label:'关闭', onClick: closeModal }] });
  setTimeout(() => {
    $('#impFileBtn').onclick = importBank;
    $('#impTplBtn').onclick = downloadTemplate;
  }, 0);
});

function exportData() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type:'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `网络刷题v2备份_${new Date().toISOString().slice(0,10)}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
  toast('已导出');
}
function importData() {
  const inp = document.createElement('input');
  inp.type = 'file'; inp.accept = 'application/json';
  inp.onchange = () => {
    const f = inp.files[0]; if (!f) return;
    const r = new FileReader();
    r.onload = () => {
      try {
        const obj = JSON.parse(r.result);
        if (!obj.schema && !obj.perQuestion) throw new Error('格式错误：缺 schema 与 perQuestion 字段');
        if (!confirm('确定要用备份覆盖当前所有学习记录吗？')) return;
        state = Object.assign(defaultState(), obj);
        saveState();
        applySettings();
        fillFilterOptions();
        startSession();
        toast('已导入');
      } catch (e) { alert('导入失败：' + e.message); }
    };
    r.readAsText(f);
  };
  inp.click();
}

/* 题库导入（不是备份）*/
function importBank() {
  const inp = document.createElement('input');
  inp.type = 'file'; inp.accept = 'application/json';
  inp.onchange = () => {
    const f = inp.files[0]; if (!f) return;
    const r = new FileReader();
    r.onload = () => {
      try {
        const obj = JSON.parse(r.result);
        // schema 校验
        const errs = validateSchema(obj);
        if (errs.length) throw new Error(errs.join('\n'));
        // 题号冲突检测
        const existingIds = new Set(activeQuestions().map(q => q.id));
        const newQs = obj.questions || [];
        const conflicts = newQs.filter(q => existingIds.has(q.id));
        let strategy = 'merge';
        if (conflicts.length) {
          const ans = prompt(
            `检测到 ${conflicts.length} 道题 ID 冲突：${conflicts.slice(0,5).map(q => q.id).join(', ')}... \n` +
            `输入策略：merge(合并) / overwrite(覆盖) / skip(跳过冲突)`
          );
          if (!ans) return;
          strategy = ['merge','overwrite','skip'].includes(ans) ? ans : 'merge';
        }
        // 合并
        const merged = state.schema.questions.slice();
        const newCat = obj.categories ? Object.assign({}, state.schema.categories, obj.categories) : state.schema.categories;
        const newTL  = obj.typeLabel   ? Object.assign({}, state.schema.typeLabel, obj.typeLabel) : state.schema.typeLabel;
        newQs.forEach(q => {
          const idx = merged.findIndex(x => x.id === q.id);
          if (idx >= 0) {
            if (strategy === 'skip') return;
            merged[idx] = q; // overwrite 或 merge 都替换
          } else {
            merged.push(q);
          }
        });
        state.schema = { questions: merged, categories: newCat, typeLabel: newTL };
        saveState();
        fillFilterOptions();
        startSession();
        toast(`已导入 ${newQs.length} 题（策略=${strategy}）`);
        $('#impResult').innerHTML = `<div class="note-box">✅ 成功导入 ${newQs.length} 题，当前题库共 ${merged.length} 题</div>`;
      } catch (e) {
        $('#impResult').innerHTML = `<div class="note-box" style="background:var(--red-bg);color:var(--red);border-color:var(--red)">❌ 导入失败：${escapeHtml(e.message)}</div>`;
      }
    };
    r.readAsText(f);
  };
  inp.click();
}

function validateSchema(obj) {
  const errs = [];
  if (!obj || typeof obj !== 'object') errs.push('根必须是对象');
  if (!Array.isArray(obj.questions)) errs.push('questions 必须是数组');
  else {
    obj.questions.forEach((q, i) => {
      if (!q.id) errs.push(`第 ${i+1} 题缺 id`);
      if (!q.type) errs.push(`${q.id || '#' + i} 缺 type`);
      if (!q.stem) errs.push(`${q.id} 缺 stem`);
      if (q.type === 'single' || q.type === 'multi') {
        if (!Array.isArray(q.options)) errs.push(`${q.id} 缺 options`);
        if (!Array.isArray(q.answer)) errs.push(`${q.id} 缺 answer 数组`);
      }
      if (q.type === 'tf' && typeof q.answer !== 'string') errs.push(`${q.id} tf 题 answer 必须是 'T' 或 'F'`);
      if (q.type === 'fill' && !Array.isArray(q.blanks)) errs.push(`${q.id} 缺 blanks`);
      if (q.type === 'short') {
        if (!q.refAnswer) errs.push(`${q.id} 简答缺 refAnswer`);
        if (!Array.isArray(q.points)) errs.push(`${q.id} 简答缺 points`);
      }
      if (q.type === 'comp') {
        if (!Array.isArray(q.parts)) errs.push(`${q.id} 综合缺 parts`);
        else q.parts.forEach((p, j) => {
          if (!p.refAnswer) errs.push(`${q.id} 第 ${j+1} 部分缺 refAnswer`);
        });
      }
      if (q.type === 'sort') {
        if (!Array.isArray(q.sortItems)) errs.push(`${q.id} 排序缺 sortItems`);
        if (!Array.isArray(q.sortKey)) errs.push(`${q.id} 排序缺 sortKey`);
      }
      if (q.type === 'match' && !Array.isArray(q.matchPairs)) errs.push(`${q.id} 连线缺 matchPairs`);
    });
  }
  return errs;
}

function downloadTemplate() {
  const tpl = {
    version: 2,
    categories: { "mycat": "我的新分类" },
    typeLabel: { "single": "单选", "tf": "判断" },
    questions: [
      {
        id: "my1", no: 100, type: "single", cat: "mycat", diff: 1,
        stem: "示例题目：以下哪个是正确的？",
        options: [{k:"A",t:"选项A"},{k:"B",t:"选项B"},{k:"C",t:"选项C"},{k:"D",t:"选项D"}],
        answer: ["A"],
        explain: "解析：选A"
      },
      {
        id: "my2", no: 101, type: "tf", cat: "mycat", diff: 1,
        stem: "这是一道判断题。",
        answer: "T",
        explain: "解析：对"
      }
    ]
  };
  const blob = new Blob([JSON.stringify(tpl, null, 2)], { type:'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = '题库导入模板.json';
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/* --------------------------------------------------------------------------
   20. 顶部菜单（移动端）/ Toast
   -------------------------------------------------------------------------- */
$('#menuToggle').addEventListener('click', () => $('#sidebar').classList.toggle('open'));
document.addEventListener('click', e => {
  if (window.innerWidth > 900) return;
  const sb = $('#sidebar');
  if (!sb.classList.contains('open')) return;
  if (e.target.closest('#sidebar') || e.target.closest('#menuToggle')) return;
  sb.classList.remove('open');
});

let toastTimer = null;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 1600);
}

/* --------------------------------------------------------------------------
   21. 键盘快捷键
   -------------------------------------------------------------------------- */
document.addEventListener('keydown', e => {
  const tag = (e.target.tagName || '').toLowerCase();
  const inField = tag === 'input' || tag === 'textarea' || e.target.isContentEditable;
  if (!current) return;
  if (e.key === 'Escape') return;
  if (inField) {
    if (e.key === 'Enter' && !e.shiftKey && (e.ctrlKey || e.metaKey)) {
      e.preventDefault(); submitAnswer();
    }
    return;
  }
  if (current.type === 'single' && /^[1-4]$/.test(e.key)) {
    const idx = Number(e.key) - 1;
    const opt = current.options[idx];
    if (opt) {
      $$('#optList label').forEach(x => x.classList.remove('sel'));
      const lab = $(`#optList label[data-k="${opt.k}"]`);
      lab.classList.add('sel');
      currentPick = opt.k;
    }
    return;
  }
  if (current.type === 'tf') {
    if (e.key === '5') { $('.tf-row button[data-pick="T"]').click(); return; }
    if (e.key === '6') { $('.tf-row button[data-pick="F"]').click(); return; }
  }
  if (e.key === 'Enter') { e.preventDefault(); submitAnswer(); return; }
  if (e.key === ' ')    { e.preventDefault(); $('#showAnsBtn').click(); return; }
  if (e.key === 'ArrowRight') { e.preventDefault(); go(1); return; }
  if (e.key === 'ArrowLeft')  { e.preventDefault(); go(-1); return; }
  if (e.key === 'f' || e.key === 'F') { e.preventDefault(); $('#favBtn').click(); return; }
  if (e.key === 'r' || e.key === 'R') { e.preventDefault(); $('#reviewBtn').click(); return; }
});

/* --------------------------------------------------------------------------
   22. 启动
   -------------------------------------------------------------------------- */
fillFilterOptions();
applySettings();
startSession();

// 暴露给开发者
window.__quiz = { state, QUESTIONS, getCard, srsUpdate, dueCount, resetAll, exportData };

})();