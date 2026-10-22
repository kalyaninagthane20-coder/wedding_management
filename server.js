// Wedding Management System - thin REST API over the MySQL database.
// All business rules live in the DATABASE (constraints, triggers, procedures);
// this server only forwards requests and shows the database's own error messages.
const express = require('express');
const mysql = require('mysql2/promise');
const path = require('path');

// Load .env by hand so it works on any Node version
try {
  require('fs').readFileSync(path.join(__dirname, '.env'), 'utf8').split(/\r?\n/).forEach((line) => {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    if (m && !line.trim().startsWith('#') && process.env[m[1]] === undefined) process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, '$2');
  });
} catch (e) { console.warn('No .env file found - using default MySQL settings (root, no password).'); }

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'wedding_db',
  dateStrings: true,
  connectionLimit: 10,
});

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const wrap = (fn) => (req, res) =>
  fn(req, res).catch((err) => {
    // sqlMessage = the exact message produced by MySQL (constraint / trigger / SIGNAL)
    res.status(400).json({ error: err.sqlMessage || err.message, code: err.code, errno: err.errno });
  });

// ---------- resources that can be written (table + primary key columns) ----------
const WRITE = {
  weddings:       { table: 'wedding',        pk: ['wedding_id'] },
  events:         { table: 'event',          pk: ['event_id'] },
  guests:         { table: 'guest',          pk: ['guest_id'] },
  invitations:    { table: 'invitation',     pk: ['guest_id', 'event_id'] },
  orders:         { table: 'catering_order', pk: ['order_id'] },
  vendorBookings: { table: 'vendor_booking', pk: ['booking_id'] },
  rooms:          { table: 'room_booking',   pk: ['room_booking_id'] },
  transport:      { table: 'transport',      pk: ['transport_id'] },
  payments:       { table: 'payment',        pk: ['payment_id'] },
  tasks:          { table: 'task',           pk: ['task_id'] },
  gifts:          { table: 'gift',           pk: ['gift_id'] },
  venues:         { table: 'venue',          pk: ['venue_id'] },
  vendors:        { table: 'vendor',         pk: ['vendor_id'] },
  caterers:       { table: 'caterer',        pk: ['caterer_id'] },
  menu:           { table: 'menu_item',      pk: ['item_id'] },
  hotels:         { table: 'hotel',          pk: ['hotel_id'] },
  planners:       { table: 'planner',        pk: ['planner_id'] },
};

const colCache = {};
async function columnsOf(table) {
  if (!colCache[table]) {
    const [rows] = await pool.query('SHOW COLUMNS FROM ??', [table]);
    colCache[table] = rows.map((r) => r.Field);
  }
  return colCache[table];
}

// keep only real columns; '' -> NULL
async function cleanBody(table, body) {
  const cols = await columnsOf(table);
  const out = {};
  for (const [k, v] of Object.entries(body || {})) {
    if (cols.includes(k)) out[k] = v === '' ? null : v;
  }
  return out;
}

// ---------- list queries (JOINs shown to the user) ----------
const LIST = {
  events: `SELECT e.*, v.venue_name, v.capacity FROM event e JOIN venue v ON v.venue_id = e.venue_id
           WHERE e.wedding_id = ? ORDER BY e.event_date, e.start_time`,
  guests: `SELECT g.*, (SELECT COUNT(*) FROM invitation i WHERE i.guest_id = g.guest_id) AS invited_to
           FROM guest g WHERE g.wedding_id = ? ORDER BY g.side, g.full_name`,
  invitations: `SELECT i.guest_id, i.event_id, g.full_name, e.event_type, e.event_date, i.rsvp_status, i.table_no, i.responded_on
                FROM invitation i JOIN guest g ON g.guest_id = i.guest_id JOIN event e ON e.event_id = i.event_id
                WHERE g.wedding_id = ? ORDER BY e.event_date, i.table_no, g.full_name`,
  orders: `SELECT co.order_id, co.event_id, co.caterer_id, e.event_type, ct.caterer_name, co.no_of_plates, co.order_status,
                  GROUP_CONCAT(mi.item_name ORDER BY mi.item_id SEPARATOR ', ') AS menu,
                  IFNULL(SUM(mi.price_per_plate),0) AS rate_per_plate,
                  co.no_of_plates * IFNULL(SUM(mi.price_per_plate),0) AS total
           FROM catering_order co JOIN event e ON e.event_id = co.event_id JOIN caterer ct ON ct.caterer_id = co.caterer_id
           LEFT JOIN order_item oi ON oi.order_id = co.order_id LEFT JOIN menu_item mi ON mi.item_id = oi.item_id
           WHERE e.wedding_id = ?
           GROUP BY co.order_id, co.event_id, co.caterer_id, e.event_type, ct.caterer_name, co.no_of_plates, co.order_status`,
  vendorBookings: `SELECT vb.*, v.vendor_name, v.service_type, e.event_type FROM vendor_booking vb
                   JOIN vendor v ON v.vendor_id = vb.vendor_id JOIN event e ON e.event_id = vb.event_id
                   WHERE e.wedding_id = ? ORDER BY e.event_date, v.service_type`,
  rooms: `SELECT rb.*, g.full_name, h.hotel_name, DATEDIFF(rb.check_out, rb.check_in) AS nights,
                 rb.rooms * DATEDIFF(rb.check_out, rb.check_in) * h.price_per_night AS cost
          FROM room_booking rb JOIN guest g ON g.guest_id = rb.guest_id JOIN hotel h ON h.hotel_id = rb.hotel_id
          WHERE g.wedding_id = ? ORDER BY rb.check_in`,
  transport: `SELECT t.*, t.vehicle_count * t.cost_per_vehicle AS cost FROM transport t WHERE wedding_id = ? ORDER BY trip_date`,
  payments: `SELECT * FROM payment WHERE wedding_id = ? ORDER BY payment_date, payment_id`,
  tasks: `SELECT * FROM task WHERE wedding_id = ? ORDER BY FIELD(status,'To Do','In Progress','Done'), due_date`,
  gifts: `SELECT gf.*, g.full_name FROM gift gf JOIN guest g ON g.guest_id = gf.guest_id WHERE g.wedding_id = ? ORDER BY gf.received_on`,
};

const DIRECTORY = {
  venues:   `SELECT v.*, (SELECT COUNT(*) FROM event e WHERE e.venue_id = v.venue_id) AS times_booked FROM venue v ORDER BY city, venue_name`,
  vendors:  `SELECT * FROM vw_vendor_directory ORDER BY service_type, rating DESC`,
  caterers: `SELECT c.*, (SELECT COUNT(*) FROM menu_item m WHERE m.caterer_id = c.caterer_id) AS menu_items FROM caterer c ORDER BY caterer_name`,
  hotels:   `SELECT * FROM hotel ORDER BY city, star_rating DESC`,
  planners: `SELECT p.*, (SELECT COUNT(*) FROM wedding w WHERE w.planner_id = p.planner_id) AS weddings FROM planner p ORDER BY full_name`,
};

app.get('/api/directory/:name', wrap(async (req, res) => {
  const sql = DIRECTORY[req.params.name];
  if (!sql) return res.status(404).json({ error: 'Unknown directory' });
  const [rows] = await pool.query(sql);
  res.json(rows);
}));

// dropdown options for forms
const OPTIONS = {
  venues:   `SELECT venue_id AS id, CONCAT(venue_name, ' - ', city, ' (cap ', capacity, ')') AS label FROM venue ORDER BY venue_name`,
  vendors:  `SELECT vendor_id AS id, CONCAT(vendor_name, ' - ', service_type) AS label FROM vendor ORDER BY service_type`,
  caterers: `SELECT caterer_id AS id, caterer_name AS label FROM caterer ORDER BY caterer_name`,
  hotels:   `SELECT hotel_id AS id, CONCAT(hotel_name, ' - ', city) AS label FROM hotel ORDER BY hotel_name`,
  planners: `SELECT planner_id AS id, full_name AS label FROM planner ORDER BY full_name`,
};
app.get('/api/options/:name', wrap(async (req, res) => {
  if (OPTIONS[req.params.name]) {
    const [rows] = await pool.query(OPTIONS[req.params.name]);
    return res.json(rows);
  }
  const w = req.query.wedding;
  if (req.params.name === 'events' && w) {
    const [rows] = await pool.query(`SELECT event_id AS id, CONCAT(event_type, ' (', event_date, ')') AS label FROM event WHERE wedding_id = ? ORDER BY event_date`, [w]);
    return res.json(rows);
  }
  if (req.params.name === 'guests' && w) {
    const [rows] = await pool.query(`SELECT guest_id AS id, CONCAT(full_name, ' (', side, ')') AS label FROM guest WHERE wedding_id = ? ORDER BY full_name`, [w]);
    return res.json(rows);
  }
  res.status(404).json({ error: 'Unknown option list' });
}));

// ---------- dashboard ----------
app.get('/api/dashboard', wrap(async (req, res) => {
  const [[stats]] = await pool.query(`
    SELECT (SELECT COUNT(*) FROM wedding WHERE status <> 'Cancelled') AS weddings,
           (SELECT COUNT(*) FROM guest) AS guests,
           (SELECT COUNT(*) FROM event WHERE event_date >= CURDATE()) AS upcoming_events,
           (SELECT IFNULL(SUM(amount),0) FROM payment) AS payments_received,
           (SELECT COUNT(*) FROM vendor_booking WHERE booking_status = 'Booked') AS vendors_booked,
           (SELECT COUNT(*) FROM task WHERE status <> 'Done') AS open_tasks`);
  const [upcoming] = await pool.query(`
    SELECT o.*, DATEDIFF(o.wedding_date, CURDATE()) AS days_left FROM vw_wedding_overview o
    WHERE o.status IN ('Planning','Confirmed') AND o.wedding_date >= CURDATE() ORDER BY o.wedding_date LIMIT 6`);
  const [rsvp] = await pool.query(`SELECT rsvp_status AS status, COUNT(*) AS n FROM invitation GROUP BY rsvp_status`);
  const [audit] = await pool.query(`SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 8`);
  res.json({ stats, upcoming, rsvp, audit });
}));

// ---------- weddings ----------
app.get('/api/weddings', wrap(async (req, res) => {
  const [rows] = await pool.query(`SELECT o.*, DATEDIFF(o.wedding_date, CURDATE()) AS days_left
                                   FROM vw_wedding_overview o ORDER BY o.wedding_date`);
  res.json(rows);
}));

app.get('/api/weddings/:id', wrap(async (req, res) => {
  const [[overview]] = await pool.query('SELECT * FROM vw_wedding_overview WHERE wedding_id = ?', [req.params.id]);
  if (!overview) return res.status(404).json({ error: 'Wedding not found' });
  const [[budget]] = await pool.query('SELECT * FROM vw_budget_status WHERE wedding_id = ?', [req.params.id]);
  const [[w]] = await pool.query('SELECT planner_id FROM wedding WHERE wedding_id = ?', [req.params.id]);
  res.json({ overview: { ...overview, planner_id: w.planner_id }, budget });
}));

// create client + wedding in ONE transaction (the trigger then creates the checklist)
app.post('/api/weddings', wrap(async (req, res) => {
  const b = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    const [c] = await conn.query(
      'INSERT INTO client (bride_name, groom_name, phone, email, city) VALUES (?,?,?,?,?)',
      [b.bride_name, b.groom_name, b.phone, b.email || null, b.city || null]);
    const [w] = await conn.query(
      'INSERT INTO wedding (client_id, planner_id, wedding_date, theme, total_budget) VALUES (?,?,?,?,?)',
      [c.insertId, b.planner_id || null, b.wedding_date, b.theme || null, b.total_budget]);
    await conn.commit();
    res.json({ wedding_id: w.insertId });
  } catch (e) { await conn.rollback(); throw e; } finally { conn.release(); }
}));

app.post('/api/weddings/:id/cancel', wrap(async (req, res) => {
  const [r] = await pool.query('CALL sp_cancel_wedding(?)', [req.params.id]);
  res.json({ message: r[0][0].result });
}));

app.get('/api/weddings/:id/:section', wrap(async (req, res) => {
  const sql = LIST[req.params.section];
  if (!sql) return res.status(404).json({ error: 'Unknown section' });
  const [rows] = await pool.query(sql, [req.params.id]);
  res.json(rows);
}));

// ---------- special actions using stored procedures ----------
app.post('/api/payments', wrap(async (req, res) => {
  const b = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.query('CALL sp_add_payment(?,?,?,?,?,@msg)',
      [b.wedding_id, b.amount, b.mode, b.paid_towards, b.reference_no || null]);
    const [[m]] = await conn.query('SELECT @msg AS message');
    if (m.message.startsWith('FAILED')) return res.status(400).json({ error: m.message });
    res.json({ message: m.message });
  } finally { conn.release(); }
}));

app.post('/api/vendorBookings', wrap(async (req, res) => {
  const b = req.body;
  const conn = await pool.getConnection();
  try {
    await conn.query('CALL sp_book_vendor(?,?,?,@msg)', [b.event_id, b.vendor_id, b.agreed_price || 0]);
    const [[m]] = await conn.query('SELECT @msg AS message');
    if (m.message.startsWith('FAILED')) return res.status(400).json({ error: m.message });
    res.json({ message: m.message });
  } finally { conn.release(); }
}));

app.post('/api/events/:id/seating', wrap(async (req, res) => {
  const [r] = await pool.query('CALL sp_assign_tables(?)', [req.params.id]);
  res.json(r[0][0]);
}));

app.get('/api/caterers/:id/menu', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM menu_item WHERE caterer_id = ? ORDER BY FIELD(course,"Welcome Drink","Starter","Main Course","Bread","Rice","Dessert","Beverage"), item_name', [req.params.id]);
  res.json(rows);
}));

app.get('/api/orders/:id/menu', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT item_id FROM order_item WHERE order_id = ?', [req.params.id]);
  res.json(rows.map((r) => r.item_id));
}));

// replace the menu of an order (delete + insert inside one transaction)
app.put('/api/orders/:id/menu', wrap(async (req, res) => {
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await conn.query('DELETE FROM order_item WHERE order_id = ?', [req.params.id]);
    for (const item of req.body.item_ids || [])
      await conn.query('INSERT INTO order_item (order_id, item_id) VALUES (?,?)', [req.params.id, item]);
    await conn.commit();
    res.json({ ok: true });
  } catch (e) { await conn.rollback(); throw e; } finally { conn.release(); }
}));

// ---------- generic create / update / delete ----------
app.post('/api/:res', wrap(async (req, res) => {
  const cfg = WRITE[req.params.res];
  if (!cfg) return res.status(404).json({ error: 'Unknown resource' });
  const data = await cleanBody(cfg.table, req.body);
  const [r] = await pool.query('INSERT INTO ?? SET ?', [cfg.table, data]);
  res.json({ id: r.insertId });
}));

app.put('/api/:res/:id', wrap(async (req, res) => {
  const cfg = WRITE[req.params.res];
  if (!cfg) return res.status(404).json({ error: 'Unknown resource' });
  const data = await cleanBody(cfg.table, req.body);
  cfg.pk.forEach((k) => delete data[k]);
  const ids = req.params.id.split('-');
  const where = cfg.pk.map((k) => `\`${k}\` = ?`).join(' AND ');
  const [r] = await pool.query(`UPDATE ?? SET ? WHERE ${where}`, [cfg.table, data, ...ids]);
  res.json({ changed: r.affectedRows });
}));

app.delete('/api/:res/:id', wrap(async (req, res) => {
  const cfg = WRITE[req.params.res];
  if (!cfg) return res.status(404).json({ error: 'Unknown resource' });
  const ids = req.params.id.split('-');
  const where = cfg.pk.map((k) => `\`${k}\` = ?`).join(' AND ');
  const [r] = await pool.query(`DELETE FROM ?? WHERE ${where}`, [cfg.table, ...ids]);
  res.json({ deleted: r.affectedRows });
}));

// ---------- DBMS lab helpers ----------
app.get('/api/lab/schema', wrap(async (req, res) => {
  const db = process.env.DB_NAME || 'wedding_db';
  const [cols] = await pool.query(
    `SELECT TABLE_NAME AS tbl, COLUMN_NAME AS col, COLUMN_TYPE AS type, IS_NULLABLE AS nullable, COLUMN_KEY AS ckey, EXTRA AS extra
     FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME, ORDINAL_POSITION`, [db]);
  const [fks] = await pool.query(
    `SELECT TABLE_NAME AS tbl, COLUMN_NAME AS col, REFERENCED_TABLE_NAME AS ref_tbl, REFERENCED_COLUMN_NAME AS ref_col
     FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = ? AND REFERENCED_TABLE_NAME IS NOT NULL`, [db]);
  const [objs] = await pool.query(
    `SELECT 'TRIGGER' AS kind, TRIGGER_NAME AS name FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = ?
     UNION ALL SELECT ROUTINE_TYPE, ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = ?
     UNION ALL SELECT 'VIEW', TABLE_NAME FROM information_schema.VIEWS WHERE TABLE_SCHEMA = ?`, [db, db, db]);
  const [counts] = await pool.query(
    `SELECT TABLE_NAME AS tbl FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_TYPE = 'BASE TABLE'`, [db]);
  const rowCounts = {};
  for (const t of counts) {
    const [[c]] = await pool.query('SELECT COUNT(*) AS n FROM ??', [t.tbl]);
    rowCounts[t.tbl] = c.n;
  }
  res.json({ cols, fks, objs, rowCounts });
}));

app.get('/api/lab/audit', wrap(async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 50');
  res.json(rows);
}));

// Read-only SQL console: SELECT/SHOW/DESCRIBE/EXPLAIN/WITH only, executed in a READ ONLY transaction
app.post('/api/lab/query', wrap(async (req, res) => {
  const sql = String(req.body.sql || '').trim().replace(/;+\s*$/, '');
  if (!/^(select|show|describe|desc|explain|with)\b/i.test(sql) || /\b(into\s+(outfile|dumpfile)|for\s+update)\b/i.test(sql))
    return res.status(400).json({ error: 'Only read-only statements (SELECT, SHOW, DESCRIBE, EXPLAIN, WITH) are allowed in this console.' });
  const conn = await pool.getConnection();
  try {
    await conn.query('START TRANSACTION READ ONLY');
    const t0 = Date.now();
    const [rows, fields] = await conn.query({ sql, rowsAsArray: true });
    const ms = Date.now() - t0;
    res.json({ columns: fields.map((f) => f.name), rows: rows.slice(0, 500), total: rows.length, ms });
  } finally {
    await conn.query('ROLLBACK').catch(() => {});
    conn.release();
  }
}));

const port = Number(process.env.PORT || 3000);
app.listen(port, '127.0.0.1', () => {
  console.log(`Wedding Management System running at http://localhost:${port}`);
  pool.query('SELECT COUNT(*) AS n FROM wedding').then(([[r]]) => console.log(`Database OK (${r.n} weddings found).`)).catch((e) => {
    console.error('\n*** DATABASE PROBLEM ***\n' + (e.sqlMessage || e.message));
    console.error('Check: 1) MySQL is running  2) you ran setup_database.bat  3) DB_USER / DB_PASSWORD in the .env file are correct\n');
  });
});
