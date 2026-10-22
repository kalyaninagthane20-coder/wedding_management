/* Wedding Management System - front end (plain JavaScript, no framework) */
const $ = (s) => document.querySelector(s);
const esc = (v) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (v) => '₹' + Number(v || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 });
const dt = (d) => (d ? new Date(d.slice(0, 10) + 'T00:00:00').toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '-');
const tm = (t) => (t ? t.slice(0, 5) : '');
const badge = (v) => `<span class="badge ${esc(String(v).replace(/ /g, '-'))}">${esc(v)}</span>`;

async function api(method, url, body) {
  const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || 'Request failed');
  return data;
}

let toastTimer;
function toast(msg, bad) {
  const t = $('#toast'); t.textContent = msg; t.className = 'toast' + (bad ? ' bad' : '');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.add('hidden'), 4200);
}
function openModal(html, wide) { $('#modal').className = 'modal' + (wide ? ' wide' : ''); $('#modal').innerHTML = html; $('#modal-bg').classList.remove('hidden'); }
function closeModal() { $('#modal-bg').classList.add('hidden'); }
$('#modal-bg').addEventListener('mousedown', (e) => { if (e.target.id === 'modal-bg') closeModal(); });

/* ---------- enum lists (same values as the MySQL ENUM columns) ---------- */
const EV = ['Engagement', 'Haldi', 'Mehendi', 'Sangeet', 'Wedding Ceremony', 'Reception'];
const SERVICES = ['Photography', 'Videography', 'Decoration', 'Florist', 'DJ & Music', 'Band Baaja', 'Makeup Artist', 'Mehendi Artist', 'Pandit', 'Lighting', 'Invitation Cards', 'Choreographer'];
const COURSES = ['Welcome Drink', 'Starter', 'Main Course', 'Bread', 'Rice', 'Dessert', 'Beverage'];

/* ---------- generic form modal ---------- */
async function loadOptions(f, wid) {
  if (f.opts) return f.opts.map((o) => ({ id: o, label: o }));
  if (f.from) return api('GET', `/api/options/${f.from}`);
  if (f.fromWedding) return api('GET', `/api/options/${f.fromWedding}?wedding=${wid}`);
  return null;
}

async function openForm({ title, fields, values = {}, wid, submitLabel = 'Save', onSubmit }) {
  const opts = await Promise.all(fields.map((f) => loadOptions(f, wid)));
  const inputs = fields.map((f, i) => {
    const v = values[f.k] ?? f.def ?? '';
    let input;
    if (opts[i]) {
      const blank = f.req ? '' : '<option value="">-- none --</option>';
      input = `<select name="${f.k}" ${f.req ? 'required' : ''}>${blank}${f.req && v === '' ? '<option value="">-- select --</option>' : ''}${opts[i].map((o) => `<option value="${esc(o.id)}" ${String(o.id) === String(v) ? 'selected' : ''}>${esc(o.label)}</option>`).join('')}</select>`;
    } else if (f.t === 'checkbox') {
      input = `<input type="checkbox" name="${f.k}" ${Number(v) === 1 || v === true ? 'checked' : ''}>`;
    } else if (f.t === 'time') {
      input = `<input type="time" name="${f.k}" value="${esc(tm(v))}" ${f.req ? 'required' : ''}>`;
    } else {
      input = `<input type="${f.t || 'text'}" name="${f.k}" value="${esc(v)}" ${f.req ? 'required' : ''} ${f.t === 'number' ? 'step="any"' : ''} ${f.max ? `maxlength="${f.max}"` : ''}>`;
    }
    return `<div class="${f.full ? 'full' : ''}"><label>${esc(f.l)}${f.req ? ' *' : ''}</label>${input}</div>`;
  }).join('');
  openModal(`<h2>${esc(title)}</h2><form id="f"><div class="form-grid">${inputs}</div><div id="ferr"></div>
    <div class="modal-actions"><button type="button" class="btn ghost" id="fcancel">Cancel</button><button class="btn">${esc(submitLabel)}</button></div></form>`);
  $('#fcancel').onclick = closeModal;
  $('#f').onsubmit = async (e) => {
    e.preventDefault();
    const body = {};
    fields.forEach((f) => {
      const el = e.target.elements[f.k];
      body[f.k] = f.t === 'checkbox' ? el.checked : el.value;
    });
    try { await onSubmit(body); closeModal(); }
    catch (err) { $('#ferr').innerHTML = `<div class="err">&#9888; ${esc(err.message)}</div>`; }
  };
}

/* ---------- entity (table) definitions ---------- */
const T = {
  events: {
    title: 'Events', res: 'events', pk: 'event_id', wid: true, hint: 'Each function of the wedding. DB trigger blocks guests above venue capacity; UNIQUE key blocks double-booking a venue on a day.',
    cols: [{ l: 'Event', k: 'event_type', f: (r) => `<b>${esc(r.event_type)}</b>` }, { l: 'Date', f: (r) => dt(r.event_date) }, { l: 'Time', f: (r) => `${tm(r.start_time)} - ${tm(r.end_time)}` },
      { l: 'Venue', k: 'venue_name' }, { l: 'Guests / Capacity', f: (r) => `${r.expected_guests} / ${r.capacity}` }],
    fields: [{ k: 'event_type', l: 'Event type', opts: EV, req: 1 }, { k: 'venue_id', l: 'Venue', from: 'venues', req: 1 }, { k: 'event_date', l: 'Date', t: 'date', req: 1 },
      { k: 'expected_guests', l: 'Expected guests', t: 'number', def: 0, req: 1 }, { k: 'start_time', l: 'Start time', t: 'time', req: 1 }, { k: 'end_time', l: 'End time', t: 'time', req: 1 }],
    actions: [{ label: 'Seating', cls: 'gold', run: async (r) => { const x = await api('POST', `/api/events/${r.event_id}/seating`); toast(`Stored procedure sp_assign_tables: ${x.guests_seated} guests seated on ${x.tables_used} tables`); } }],
  },
  guests: {
    title: 'Guest List', res: 'guests', pk: 'guest_id', wid: true, hint: 'Inserts and deletes here are logged automatically by database triggers (see DBMS Lab > Audit log).',
    cols: [{ l: 'Name', f: (r) => `<b>${esc(r.full_name)}</b>` }, { l: 'Side', k: 'side' }, { l: 'Relation', k: 'relation' }, { l: 'Meal', k: 'meal_preference' }, { l: '+1s', k: 'plus_ones', num: 1 }, { l: 'City', k: 'city' }, { l: 'Phone', k: 'phone' }, { l: 'Events', k: 'invited_to', num: 1 }],
    fields: [{ k: 'full_name', l: 'Full name', req: 1, full: 1 }, { k: 'side', l: 'Side', opts: ['Bride', 'Groom'], req: 1 }, { k: 'relation', l: 'Relation' }, { k: 'meal_preference', l: 'Meal preference', opts: ['Veg', 'Non-Veg', 'Jain', 'Vegan'], req: 1, def: 'Veg' },
      { k: 'plus_ones', l: 'Plus ones (max 5)', t: 'number', def: 0 }, { k: 'city', l: 'City' }, { k: 'phone', l: 'Phone (10 digits)', max: 10 }, { k: 'email', l: 'Email', t: 'email' }],
  },
  invitations: {
    title: 'Invitations & RSVP', res: 'invitations', wid: true, noWid: true, hint: 'Many-to-many between GUEST and EVENT (composite primary key). Changing the RSVP fires a trigger that stamps the response time.',
    id: (r) => `${r.guest_id}-${r.event_id}`,
    cols: [{ l: 'Guest', f: (r) => `<b>${esc(r.full_name)}</b>` }, { l: 'Event', k: 'event_type' }, { l: 'Date', f: (r) => dt(r.event_date) },
      { l: 'RSVP', k: 'rsvp_status', inline: ['Pending', 'Accepted', 'Declined'] }, { l: 'Table', f: (r) => r.table_no ?? '-' }, { l: 'Responded', f: (r) => (r.responded_on ? r.responded_on.slice(0, 16) : '-') }],
    fields: [{ k: 'guest_id', l: 'Guest', fromWedding: 'guests', req: 1 }, { k: 'event_id', l: 'Event', fromWedding: 'events', req: 1 }, { k: 'rsvp_status', l: 'RSVP', opts: ['Pending', 'Accepted', 'Declined'], def: 'Pending', req: 1 }],
    editFields: [{ k: 'rsvp_status', l: 'RSVP', opts: ['Pending', 'Accepted', 'Declined'], req: 1 }, { k: 'table_no', l: 'Table no', t: 'number' }],
  },
  orders: {
    title: 'Catering', res: 'orders', pk: 'order_id', wid: true, noWid: true, hint: 'Each event has one catering order (1:1). The menu is a many-to-many (ORDER_ITEM). A trigger rejects dishes from another caterer.',
    cols: [{ l: 'Event', k: 'event_type', f: (r) => `<b>${esc(r.event_type)}</b>` }, { l: 'Caterer', k: 'caterer_name' }, { l: 'Plates', k: 'no_of_plates', num: 1 }, { l: 'Status', k: 'order_status', badge: 1 },
      { l: 'Menu', f: (r) => `<span class="small">${esc(r.menu || 'No items chosen')}</span>` }, { l: 'Rate/plate', f: (r) => money(r.rate_per_plate), num: 1 }, { l: 'Total', f: (r) => `<b>${money(r.total)}</b>`, num: 1 }],
    fields: [{ k: 'event_id', l: 'Event', fromWedding: 'events', req: 1 }, { k: 'caterer_id', l: 'Caterer', from: 'caterers', req: 1 }, { k: 'no_of_plates', l: 'Number of plates', t: 'number', req: 1 }, { k: 'order_status', l: 'Status', opts: ['Quoted', 'Confirmed', 'Served', 'Cancelled'], def: 'Quoted', req: 1 }],
    editFields: [{ k: 'no_of_plates', l: 'Number of plates', t: 'number', req: 1 }, { k: 'order_status', l: 'Status', opts: ['Quoted', 'Confirmed', 'Served', 'Cancelled'], req: 1 }],
    actions: [{ label: 'Menu', cls: 'gold', run: (r, reload) => pickMenu(r, reload) }],
  },
  vendorBookings: {
    title: 'Vendors', res: 'vendorBookings', pk: 'booking_id', wid: true, noWid: true, hint: 'Booking uses the stored procedure sp_book_vendor (transaction + availability check).',
    cols: [{ l: 'Event', k: 'event_type' }, { l: 'Vendor', f: (r) => `<b>${esc(r.vendor_name)}</b>` }, { l: 'Service', k: 'service_type' }, { l: 'Agreed price', f: (r) => money(r.agreed_price), num: 1 }, { l: 'Status', k: 'booking_status', badge: 1 }],
    fields: [{ k: 'event_id', l: 'Event', fromWedding: 'events', req: 1 }, { k: 'vendor_id', l: 'Vendor', from: 'vendors', req: 1 }, { k: 'agreed_price', l: 'Agreed price', t: 'number', req: 1 }],
    editFields: [{ k: 'agreed_price', l: 'Agreed price', t: 'number', req: 1 }, { k: 'booking_status', l: 'Status', opts: ['Enquired', 'Booked', 'Completed', 'Cancelled'], req: 1 }],
  },
  rooms: {
    title: 'Guest Stay', res: 'rooms', pk: 'room_booking_id', wid: true, noWid: true, hint: 'Hotel rooms for outstation guests. Cost = rooms x nights x price per night.',
    cols: [{ l: 'Guest', f: (r) => `<b>${esc(r.full_name)}</b>` }, { l: 'Hotel', k: 'hotel_name' }, { l: 'Room', f: (r) => `${r.rooms} x ${esc(r.room_type)}` }, { l: 'Check-in', f: (r) => dt(r.check_in) }, { l: 'Check-out', f: (r) => dt(r.check_out) }, { l: 'Nights', k: 'nights', num: 1 }, { l: 'Cost', f: (r) => money(r.cost), num: 1 }],
    fields: [{ k: 'guest_id', l: 'Guest', fromWedding: 'guests', req: 1 }, { k: 'hotel_id', l: 'Hotel', from: 'hotels', req: 1 }, { k: 'room_type', l: 'Room type', opts: ['Single', 'Double', 'Suite'], def: 'Double', req: 1 }, { k: 'rooms', l: 'Rooms', t: 'number', def: 1, req: 1 }, { k: 'check_in', l: 'Check-in', t: 'date', req: 1 }, { k: 'check_out', l: 'Check-out', t: 'date', req: 1 }],
  },
  transport: {
    title: 'Transport', res: 'transport', pk: 'transport_id', wid: true, hint: 'Baraat vehicles, airport pickups and guest shuttles.',
    cols: [{ l: 'Vehicle', f: (r) => `<b>${r.vehicle_count} x ${esc(r.vehicle_type)}</b>` }, { l: 'Purpose', k: 'purpose' }, { l: 'Route', f: (r) => `${esc(r.pickup_point || '')} &rarr; ${esc(r.drop_point || '')}` }, { l: 'Date', f: (r) => dt(r.trip_date) }, { l: 'Cost', f: (r) => money(r.cost), num: 1 }],
    fields: [{ k: 'vehicle_type', l: 'Vehicle', opts: ['Car', 'SUV', 'Tempo Traveller', 'Bus', 'Vintage Car', 'Horse (Ghodi)'], req: 1 }, { k: 'vehicle_count', l: 'Count', t: 'number', def: 1, req: 1 }, { k: 'cost_per_vehicle', l: 'Cost per vehicle', t: 'number', req: 1 }, { k: 'trip_date', l: 'Date', t: 'date', req: 1 }, { k: 'pickup_point', l: 'Pickup' }, { k: 'drop_point', l: 'Drop' }, { k: 'purpose', l: 'Purpose', full: 1 }],
  },
  payments: {
    title: 'Payments', res: 'payments', pk: 'payment_id', wid: true, hint: 'Adding a payment calls stored procedure sp_add_payment. A trigger refuses payments that would exceed the budget.',
    cols: [{ l: 'Date', f: (r) => dt(r.payment_date) }, { l: 'Amount', f: (r) => `<b>${money(r.amount)}</b>`, num: 1 }, { l: 'Mode', k: 'mode' }, { l: 'Towards', k: 'paid_towards' }, { l: 'Reference', k: 'reference_no' }],
    fields: [{ k: 'amount', l: 'Amount', t: 'number', req: 1 }, { k: 'payment_date', l: 'Date', t: 'date' }, { k: 'mode', l: 'Mode', opts: ['Cash', 'UPI', 'Card', 'Bank Transfer', 'Cheque'], req: 1, def: 'UPI' }, { k: 'paid_towards', l: 'Paid towards', opts: ['Advance', 'Venue', 'Catering', 'Vendor', 'Accommodation', 'Transport', 'Planner Fee', 'Other'], req: 1, def: 'Advance' }, { k: 'reference_no', l: 'Reference no', full: 1 }],
  },
  tasks: {
    title: 'Checklist', res: 'tasks', pk: 'task_id', wid: true, hint: 'The first six tasks were created automatically by a trigger when the wedding was added.',
    cols: [{ l: 'Task', f: (r) => `<b>${esc(r.title)}</b>` }, { l: 'Category', k: 'category' }, { l: 'Due', f: (r) => dt(r.due_date) }, { l: 'Priority', k: 'priority', badge: 1 }, { l: 'Status', k: 'status', inline: ['To Do', 'In Progress', 'Done'] }],
    fields: [{ k: 'title', l: 'Task', req: 1, full: 1 }, { k: 'category', l: 'Category', opts: ['Venue', 'Catering', 'Guests', 'Vendors', 'Shopping', 'Rituals', 'Logistics', 'Other'], def: 'Other', req: 1 }, { k: 'due_date', l: 'Due date', t: 'date' }, { k: 'priority', l: 'Priority', opts: ['Low', 'Medium', 'High'], def: 'Medium', req: 1 }, { k: 'status', l: 'Status', opts: ['To Do', 'In Progress', 'Done'], def: 'To Do', req: 1 }],
  },
  gifts: {
    title: 'Gifts', res: 'gifts', pk: 'gift_id', wid: true, noWid: true, hint: 'Track shagun / gifts and thank-you notes.',
    cols: [{ l: 'From', f: (r) => `<b>${esc(r.full_name)}</b>` }, { l: 'Type', k: 'gift_type' }, { l: 'Description', k: 'description' }, { l: 'Value', f: (r) => money(r.estimated_value), num: 1 }, { l: 'Received', f: (r) => dt(r.received_on) }, { l: 'Thank-you sent', f: (r) => (Number(r.thank_you_sent) ? '&#10003; Yes' : 'No') }],
    fields: [{ k: 'guest_id', l: 'Guest', fromWedding: 'guests', req: 1 }, { k: 'gift_type', l: 'Type', opts: ['Cash', 'Jewellery', 'Electronics', 'Home Decor', 'Clothing', 'Other'], req: 1 }, { k: 'description', l: 'Description', full: 1 }, { k: 'estimated_value', l: 'Estimated value', t: 'number', def: 0 }, { k: 'received_on', l: 'Received on', t: 'date' }, { k: 'thank_you_sent', l: 'Thank-you sent', t: 'checkbox' }],
  },
};

const DIR = {
  venues: { title: 'Venues', res: 'venues', pk: 'venue_id', url: '/api/directory/venues', hint: 'Halls, lawns and resorts. Deleting a venue that has events is blocked by ON DELETE RESTRICT.',
    cols: [{ l: 'Venue', f: (r) => `<b>${esc(r.venue_name)}</b>` }, { l: 'Type', k: 'venue_type' }, { l: 'City', k: 'city' }, { l: 'Capacity', k: 'capacity', num: 1 }, { l: 'Price / day', f: (r) => money(r.price_per_day), num: 1 }, { l: 'Booked', k: 'times_booked', num: 1 }],
    fields: [{ k: 'venue_name', l: 'Venue name', req: 1, full: 1 }, { k: 'venue_type', l: 'Type', opts: ['Banquet Hall', 'Lawn', 'Resort', 'Temple', 'Hotel', 'Farmhouse'], req: 1 }, { k: 'city', l: 'City', req: 1 }, { k: 'capacity', l: 'Capacity', t: 'number', req: 1 }, { k: 'price_per_day', l: 'Price per day', t: 'number', req: 1 }, { k: 'address', l: 'Address', full: 1 }] },
  vendors: { title: 'Vendors', res: 'vendors', pk: 'vendor_id', url: '/api/directory/vendors', hint: 'Photographers, decorators, DJs, pandits... (from the view vw_vendor_directory).',
    cols: [{ l: 'Vendor', f: (r) => `<b>${esc(r.vendor_name)}</b>` }, { l: 'Service', k: 'service_type' }, { l: 'City', k: 'city' }, { l: 'Base price', f: (r) => money(r.base_price), num: 1 }, { l: 'Rating', f: (r) => `&#9733; ${r.rating ?? '-'}` }, { l: 'Bookings', k: 'times_booked', num: 1 }],
    fields: [{ k: 'vendor_name', l: 'Vendor name', req: 1, full: 1 }, { k: 'service_type', l: 'Service', opts: SERVICES, req: 1 }, { k: 'city', l: 'City' }, { k: 'phone', l: 'Phone (10 digits)', req: 1, max: 10 }, { k: 'base_price', l: 'Base price', t: 'number', req: 1 }, { k: 'rating', l: 'Rating (0-5)', t: 'number' }] },
  caterers: { title: 'Caterers', res: 'caterers', pk: 'caterer_id', url: '/api/directory/caterers', hint: 'Each caterer has its own menu (one-to-many).',
    cols: [{ l: 'Caterer', f: (r) => `<b>${esc(r.caterer_name)}</b>` }, { l: 'Speciality', k: 'speciality' }, { l: 'City', k: 'city' }, { l: 'Phone', k: 'phone' }, { l: 'Rating', f: (r) => `&#9733; ${r.rating ?? '-'}` }, { l: 'Menu items', k: 'menu_items', num: 1 }],
    fields: [{ k: 'caterer_name', l: 'Caterer name', req: 1, full: 1 }, { k: 'speciality', l: 'Speciality' }, { k: 'city', l: 'City' }, { k: 'phone', l: 'Phone (10 digits)', req: 1, max: 10 }, { k: 'rating', l: 'Rating (0-5)', t: 'number' }],
    actions: [{ label: 'Menu', cls: 'gold', run: (r, reload) => manageMenu(r, reload) }] },
  hotels: { title: 'Hotels', res: 'hotels', pk: 'hotel_id', url: '/api/directory/hotels', hint: 'Accommodation for outstation guests.',
    cols: [{ l: 'Hotel', f: (r) => `<b>${esc(r.hotel_name)}</b>` }, { l: 'City', k: 'city' }, { l: 'Stars', f: (r) => '&#9733;'.repeat(r.star_rating) }, { l: 'Price / night', f: (r) => money(r.price_per_night), num: 1 }, { l: 'Phone', k: 'phone' }],
    fields: [{ k: 'hotel_name', l: 'Hotel name', req: 1, full: 1 }, { k: 'city', l: 'City', req: 1 }, { k: 'star_rating', l: 'Stars (1-5)', t: 'number', req: 1 }, { k: 'price_per_night', l: 'Price per night', t: 'number', req: 1 }, { k: 'phone', l: 'Phone', max: 10 }] },
  planners: { title: 'Wedding Planners', res: 'planners', pk: 'planner_id', url: '/api/directory/planners', hint: 'One planner can handle many weddings; deleting a planner sets wedding.planner_id to NULL (ON DELETE SET NULL).',
    cols: [{ l: 'Planner', f: (r) => `<b>${esc(r.full_name)}</b>` }, { l: 'Phone', k: 'phone' }, { l: 'Email', k: 'email' }, { l: 'Experience', f: (r) => `${r.experience_years} yrs` }, { l: 'Fee', f: (r) => money(r.fee), num: 1 }, { l: 'Weddings', k: 'weddings', num: 1 }],
    fields: [{ k: 'full_name', l: 'Full name', req: 1, full: 1 }, { k: 'phone', l: 'Phone (10 digits)', req: 1, max: 10 }, { k: 'email', l: 'Email', t: 'email' }, { k: 'experience_years', l: 'Experience (years)', t: 'number', def: 0 }, { k: 'fee', l: 'Fee', t: 'number', def: 0 }] },
};

/* ---------- generic table + CRUD ---------- */
async function showEntity(box, cfg, wid) {
  const url = cfg.url || `/api/weddings/${wid}/${cfg.res}`;
  const rows = await api('GET', url);
  const idOf = cfg.id || ((r) => r[cfg.pk]);
  const reload = () => showEntity(box, cfg, wid);
  const head = cfg.cols.map((c) => `<th class="${c.num ? 'num' : ''}">${c.l}</th>`).join('') + '<th></th>';
  const cell = (c, r, i) => {
    let inner;
    if (c.inline) inner = `<select data-inline="${c.k}" data-i="${i}" style="width:auto;padding:3px 6px">${c.inline.map((o) => `<option ${r[c.k] === o ? 'selected' : ''}>${esc(o)}</option>`).join('')}</select>`;
    else if (c.badge) inner = badge(r[c.k]);
    else if (c.f) inner = c.f(r);
    else inner = esc(r[c.k] ?? '-');
    return `<td class="${c.num ? 'num' : ''}">${inner}</td>`;
  };
  const body = rows.length
    ? rows.map((r, i) => `<tr>${cfg.cols.map((c) => cell(c, r, i)).join('')}<td class="actions">${(cfg.actions || []).map((a, j) => `<button class="btn sm ${a.cls || ''}" data-act="x" data-j="${j}" data-i="${i}">${a.label}</button>`).join('')}
        <button class="btn sm ghost" data-act="edit" data-i="${i}">Edit</button><button class="btn sm danger" data-act="del" data-i="${i}">Delete</button></td></tr>`).join('')
    : `<tr><td colspan="${cfg.cols.length + 1}" class="empty">Nothing here yet. Click "Add" to create the first record.</td></tr>`;
  box.innerHTML = `<div class="toolbar"><span class="hint">${esc(cfg.hint || '')}</span><button class="btn" data-act="add">+ Add</button></div>
    <div class="tbl-wrap"><table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table></div>`;

  const save = (method, path, body) => api(method, path, body);
  box.onclick = async (e) => {
    const b = e.target.closest('[data-act]'); if (!b) return;
    const row = rows[b.dataset.i];
    try {
      if (b.dataset.act === 'add') {
        await openForm({ title: `Add - ${cfg.title}`, fields: cfg.fields, wid, onSubmit: async (v) => {
          if (cfg.wid && !cfg.noWid) v.wedding_id = wid;
          await save('POST', `/api/${cfg.res}`, v); toast('Saved'); reload();
        } });
      } else if (b.dataset.act === 'edit') {
        await openForm({ title: `Edit - ${cfg.title}`, fields: cfg.editFields || cfg.fields, values: row, wid, onSubmit: async (v) => {
          await save('PUT', `/api/${cfg.res}/${idOf(row)}`, v); toast('Updated'); reload();
        } });
      } else if (b.dataset.act === 'del') {
        if (!confirm('Delete this record? (Related rows may be deleted by ON DELETE CASCADE)')) return;
        await save('DELETE', `/api/${cfg.res}/${idOf(row)}`); toast('Deleted'); reload();
      } else if (b.dataset.act === 'x') {
        await cfg.actions[b.dataset.j].run(row, reload);
      }
    } catch (err) { toast(err.message, true); }
  };
  box.onchange = async (e) => {
    const s = e.target.closest('[data-inline]'); if (!s) return;
    const row = rows[s.dataset.i];
    try { await api('PUT', `/api/${cfg.res}/${idOf(row)}`, { [s.dataset.inline]: s.value }); toast('Updated'); reload(); }
    catch (err) { toast(err.message, true); reload(); }
  };
}

/* ---------- menu pickers ---------- */
async function pickMenu(order, reload) {
  const [items, chosen] = await Promise.all([api('GET', `/api/caterers/${order.caterer_id}/menu`), api('GET', `/api/orders/${order.order_id}/menu`)]);
  const groups = COURSES.map((c) => ({ c, list: items.filter((i) => i.course === c) })).filter((g) => g.list.length);
  openModal(`<h2>Menu - ${esc(order.event_type)} (${esc(order.caterer_name)})</h2><p class="small">Tick the dishes for this event. Saved in one transaction.</p>
    <div class="menu-pick">${groups.map((g) => `<h4>${g.c}</h4>${g.list.map((i) => `<label><input type="checkbox" value="${i.item_id}" ${chosen.includes(i.item_id) ? 'checked' : ''}> ${esc(i.item_name)} (${i.food_type === 'Veg' ? '&#127807;' : '&#127830;'} ${money(i.price_per_plate)})</label>`).join('')}`).join('')}</div>
    <div id="ferr"></div><div class="modal-actions"><button class="btn ghost" id="mc">Cancel</button><button class="btn" id="ms">Save menu</button></div>`);
  $('#mc').onclick = closeModal;
  $('#ms').onclick = async () => {
    const ids = [...document.querySelectorAll('.menu-pick input:checked')].map((x) => Number(x.value));
    try { await api('PUT', `/api/orders/${order.order_id}/menu`, { item_ids: ids }); closeModal(); toast('Menu saved'); reload(); }
    catch (err) { $('#ferr').innerHTML = `<div class="err">&#9888; ${esc(err.message)}</div>`; }
  };
}

async function manageMenu(caterer, reload) {
  const items = await api('GET', `/api/caterers/${caterer.caterer_id}/menu`);
  openModal(`<h2>Menu - ${esc(caterer.caterer_name)}</h2>
    <div class="tbl-wrap" style="max-height:34vh"><table><thead><tr><th>Item</th><th>Course</th><th>Type</th><th class="num">Price</th><th></th></tr></thead><tbody>
    ${items.map((i) => `<tr><td>${esc(i.item_name)}</td><td>${esc(i.course)}</td><td>${esc(i.food_type)}</td><td class="num">${money(i.price_per_plate)}</td><td class="actions"><button class="btn sm danger" data-del="${i.item_id}">&#10005;</button></td></tr>`).join('') || '<tr><td colspan="5" class="empty">No items</td></tr>'}</tbody></table></div>
    <h3 style="margin-top:14px">Add dish</h3>
    <form id="mf"><div class="form-grid"><div class="full"><label>Dish name</label><input name="item_name" required></div>
    <div><label>Course</label><select name="course">${COURSES.map((c) => `<option>${c}</option>`).join('')}</select></div>
    <div><label>Type</label><select name="food_type"><option>Veg</option><option>Non-Veg</option></select></div>
    <div><label>Price per plate</label><input name="price_per_plate" type="number" step="any" required></div></div><div id="ferr"></div>
    <div class="modal-actions"><button type="button" class="btn ghost" id="mc">Close</button><button class="btn">Add dish</button></div></form>`, true);
  $('#mc').onclick = () => { closeModal(); reload(); };
  $('#mf').onsubmit = async (e) => {
    e.preventDefault();
    const v = Object.fromEntries(new FormData(e.target)); v.caterer_id = caterer.caterer_id;
    try { await api('POST', '/api/menu', v); manageMenu(caterer, reload); } catch (err) { $('#ferr').innerHTML = `<div class="err">&#9888; ${esc(err.message)}</div>`; }
  };
  document.querySelectorAll('[data-del]').forEach((b) => (b.onclick = async () => {
    try { await api('DELETE', `/api/menu/${b.dataset.del}`); manageMenu(caterer, reload); } catch (err) { toast(err.message, true); }
  }));
}

/* ---------- pages ---------- */
const view = $('#view');
function setNav(n) { document.querySelectorAll('#nav a').forEach((a) => a.classList.toggle('active', a.dataset.n === n)); }

async function pageDashboard() {
  setNav('dashboard');
  const d = await api('GET', '/api/dashboard');
  const s = d.stats;
  const statCards = [['Weddings', s.weddings], ['Guests', s.guests], ['Upcoming events', s.upcoming_events], ['Vendors booked', s.vendors_booked], ['Open tasks', s.open_tasks], ['Payments received', money(s.payments_received)]]
    .map(([l, n]) => `<div class="card stat"><div class="num">${n}</div><div class="lbl">${l}</div></div>`).join('');
  const totalR = d.rsvp.reduce((a, b) => a + b.n, 0) || 1;
  view.innerHTML = `<div class="page-head"><div><h1>Welcome, Wedding Planner &#128144;</h1><p>Everything for the big day - venues, guests, catering, vendors, stay and budget - in one MySQL database.</p></div>
      <button class="btn gold" onclick="newWedding()">+ New Wedding</button></div>
    <div class="grid g-stats">${statCards}</div>
    <h2 style="margin-top:26px">Upcoming Weddings</h2>
    <div class="grid g-cards">${d.upcoming.map(weddingCard).join('') || '<div class="card empty">No upcoming weddings</div>'}</div>
    <div class="grid g-2" style="margin-top:26px">
      <div class="card"><h3>RSVP Status (all events)</h3>${d.rsvp.map((r) => `<div class="bar-row"><span class="lab">${badge(r.status)}</span><div class="bar"><i style="width:${(r.n / totalR) * 100}%"></i></div><span class="val">${r.n}</span></div>`).join('')}</div>
      <div class="card"><h3>Recent Database Activity <span class="small">(audit_log written by triggers)</span></h3>
        ${d.audit.map((a) => `<div class="small" style="padding:4px 0;border-bottom:1px dotted var(--line)"><b>${esc(a.action)}</b> ${esc(a.table_name)} - ${esc(a.details)} <span style="float:right">${esc(a.logged_at.slice(5, 16))}</span></div>`).join('') || '<div class="small">No activity yet</div>'}</div>
    </div>`;
}

function weddingCard(w) {
  const dl = w.days_left;
  const cd = w.status === 'Cancelled' ? '' : dl > 0 ? `<div class="countdown">${dl} days to go</div>` : dl === 0 ? '<div class="countdown">Today!</div>' : `<div class="small">${-dl} days ago</div>`;
  return `<div class="card wcard" onclick="location.hash='#/wedding/${w.wedding_id}/overview'">
    <div style="display:flex;justify-content:space-between;align-items:start"><h3>${esc(w.couple)}</h3>${badge(w.status)}</div>${cd}
    <div class="meta">&#128197; ${dt(w.wedding_date)} &nbsp; &#127912; ${esc(w.theme || '-')}<br>&#128205; ${esc(w.client_city || '-')} &nbsp; &#128101; ${w.no_of_guests} guests &nbsp; &#127881; ${w.no_of_events} events<br>&#129309; Planner: ${esc(w.planner)}<br>&#128176; Budget ${money(w.total_budget)}</div></div>`;
}

async function pageWeddings() {
  setNav('weddings');
  const rows = await api('GET', '/api/weddings');
  view.innerHTML = `<div class="page-head"><div><h1>Weddings</h1><p>All bookings (from view <code>vw_wedding_overview</code>)</p></div><button class="btn gold" onclick="newWedding()">+ New Wedding</button></div>
    <div class="grid g-cards">${rows.map(weddingCard).join('')}</div>`;
}

async function newWedding() {
  await openForm({ title: 'New Wedding Booking', submitLabel: 'Create wedding', fields: [
    { k: 'bride_name', l: 'Bride name', req: 1 }, { k: 'groom_name', l: 'Groom name', req: 1 }, { k: 'phone', l: 'Contact phone (10 digits)', req: 1, max: 10 }, { k: 'email', l: 'Email', t: 'email' },
    { k: 'city', l: 'City' }, { k: 'planner_id', l: 'Planner', from: 'planners' }, { k: 'wedding_date', l: 'Wedding date', t: 'date', req: 1 }, { k: 'total_budget', l: 'Total budget', t: 'number', req: 1 }, { k: 'theme', l: 'Theme', full: 1 }],
  onSubmit: async (v) => { const r = await api('POST', '/api/weddings', v); toast('Wedding created. A starter checklist was added by a trigger.'); location.hash = `#/wedding/${r.wedding_id}/tasks`; } });
}

const TABS = [['overview', 'Overview'], ['events', 'Events'], ['guests', 'Guests'], ['invitations', 'RSVP'], ['orders', 'Catering'], ['vendorBookings', 'Vendors'], ['rooms', 'Stay'], ['transport', 'Transport'], ['payments', 'Payments'], ['tasks', 'Checklist'], ['gifts', 'Gifts']];

async function pageWedding(id, tab) {
  setNav('weddings');
  const { overview: o, budget: b } = await api('GET', `/api/weddings/${id}`);
  view.innerHTML = `<div class="page-head"><div><a href="#/weddings">&larr; All weddings</a><h1>${esc(o.couple)} ${badge(o.status)}</h1>
      <p>&#128197; ${dt(o.wedding_date)} &middot; ${esc(o.theme || '')} &middot; Planner: ${esc(o.planner)}</p></div></div>
    <div class="tabs">${TABS.map(([k, l]) => `<a href="#/wedding/${id}/${k}" class="${k === tab ? 'active' : ''}">${l}</a>`).join('')}</div><div id="tabbox"></div>`;
  const box = $('#tabbox');
  if (tab === 'overview') return overviewTab(box, id, o, b);
  await showEntity(box, T[tab], id);
}

function overviewTab(box, id, o, b) {
  const budget = Number(b.total_budget);
  const parts = [['Venue', b.venue_cost], ['Catering', b.catering_cost], ['Vendors', b.vendor_cost], ['Guest stay', b.accommodation_cost], ['Transport', b.transport_cost], ['Planner fee', b.planner_fee]];
  const over = Number(b.total_expense) > budget;
  box.innerHTML = `<div class="grid g-2">
    <div class="card"><h3>Budget Breakdown</h3><p class="small">Computed by MySQL stored functions via view <code>vw_budget_status</code>.</p>
      ${parts.map(([l, v]) => `<div class="bar-row"><span class="lab">${l}</span><div class="bar"><i style="width:${Math.min(100, (Number(v) / budget) * 100)}%"></i></div><span class="val">${money(v)}</span></div>`).join('')}
      <hr style="border:0;border-top:1px solid var(--line)">
      <div class="bar-row"><span class="lab"><b>Total expense</b></span><div class="bar ${over ? 'over' : ''}"><i style="width:${Math.min(100, (Number(b.total_expense) / budget) * 100)}%"></i></div><span class="val"><b>${money(b.total_expense)}</b></span></div>
      <div class="bar-row"><span class="lab">Budget</span><div class="bar"><i style="width:100%;background:var(--gold)"></i></div><span class="val">${money(budget)}</span></div>
      <p style="color:${over ? 'var(--bad)' : 'var(--ok)'}">${over ? '&#9888; Over budget by ' + money(-b.budget_remaining) : '&#10003; ' + money(b.budget_remaining) + ' left in budget'}</p></div>
    <div class="card"><h3>Payments</h3><div class="big-money">${money(b.amount_paid)}</div><div class="small">paid so far</div>
      <div class="bar" style="margin:12px 0"><i style="width:${Math.min(100, (Number(b.amount_paid) / Math.max(1, Number(b.total_expense))) * 100)}%"></i></div>
      <div class="kv"><b>Balance due</b><span>${money(b.balance_due)}</span><b>Events</b><span>${o.no_of_events}</span><b>Guests</b><span>${o.no_of_guests}</span><b>Client city</b><span>${esc(o.client_city || '-')}</span></div>
      <div style="margin-top:18px;display:flex;gap:8px;flex-wrap:wrap">
        <button class="btn" id="bedit">Edit wedding</button>
        <button class="btn ghost" id="bcancel">Cancel wedding</button>
        <button class="btn danger" id="bdel">Delete</button></div>
      <p class="small">Cancel runs stored procedure <code>sp_cancel_wedding</code> (one transaction). Delete uses ON DELETE CASCADE.</p></div></div>`;
  $('#bedit').onclick = () => openForm({ title: 'Edit Wedding', values: { ...o, wedding_date: o.wedding_date, total_budget: o.total_budget }, fields: [
    { k: 'wedding_date', l: 'Date', t: 'date', req: 1 }, { k: 'theme', l: 'Theme' }, { k: 'total_budget', l: 'Total budget', t: 'number', req: 1 },
    { k: 'status', l: 'Status', opts: ['Planning', 'Confirmed', 'Completed', 'Cancelled'], req: 1 }, { k: 'planner_id', l: 'Planner', from: 'planners' }],
  onSubmit: async (v) => { await api('PUT', `/api/weddings/${id}`, v); toast('Wedding updated (status changes are logged by a trigger)'); route(); } });
  $('#bcancel').onclick = async () => {
    if (!confirm('Cancel this wedding and all its vendor bookings / catering orders?')) return;
    try { const r = await api('POST', `/api/weddings/${id}/cancel`); toast(r.message); route(); } catch (e) { toast(e.message, true); }
  };
  $('#bdel').onclick = async () => {
    if (!confirm('Permanently delete this wedding with ALL its events, guests, payments and tasks?')) return;
    try { await api('DELETE', `/api/weddings/${id}`); toast('Wedding deleted'); location.hash = '#/weddings'; } catch (e) { toast(e.message, true); }
  };
}

async function pageDirectory(name) {
  setNav(name);
  const cfg = DIR[name];
  view.innerHTML = `<div class="page-head"><div><h1>${cfg.title}</h1></div></div><div id="tabbox"></div>`;
  await showEntity($('#tabbox'), cfg, null);
}

/* ---------- DBMS lab ---------- */
const SAMPLES = [
  ['Join: events with couple and venue', `SELECT CONCAT(c.bride_name,' & ',c.groom_name) AS couple, e.event_type, e.event_date, v.venue_name\nFROM event e JOIN wedding w ON w.wedding_id=e.wedding_id\nJOIN client c ON c.client_id=w.client_id JOIN venue v ON v.venue_id=e.venue_id\nORDER BY e.event_date`],
  ['Aggregate: guests per wedding by side', `SELECT wedding_id, COUNT(*) AS guests, SUM(side='Bride') AS bride_side, SUM(side='Groom') AS groom_side\nFROM guest GROUP BY wedding_id HAVING COUNT(*) > 4`],
  ['Left join: planners and workload', `SELECT p.full_name, COUNT(w.wedding_id) AS weddings\nFROM planner p LEFT JOIN wedding w ON w.planner_id=p.planner_id GROUP BY p.planner_id, p.full_name`],
  ['Subquery: venues above average price', `SELECT venue_name, price_per_day FROM venue\nWHERE price_per_day > (SELECT AVG(price_per_day) FROM venue)`],
  ['Correlated subquery / EXISTS', `SELECT w.wedding_id, w.theme FROM wedding w\nWHERE EXISTS (SELECT 1 FROM guest g JOIN invitation i ON i.guest_id=g.guest_id\n  WHERE g.wedding_id=w.wedding_id AND i.rsvp_status='Pending')`],
  ['Window function: rank vendors by rating', `SELECT service_type, vendor_name, rating,\n  RANK() OVER (PARTITION BY service_type ORDER BY rating DESC) AS rnk\nFROM vendor`],
  ['Running total of payments', `SELECT wedding_id, payment_date, amount,\n  SUM(amount) OVER (PARTITION BY wedding_id ORDER BY payment_date, payment_id) AS running_total\nFROM payment`],
  ['CTE + stored function: budget used', `WITH spend AS (SELECT wedding_id, fn_total_expense(wedding_id) AS expense FROM wedding)\nSELECT w.wedding_id, w.total_budget, s.expense, ROUND(s.expense/w.total_budget*100,1) AS pct_used\nFROM wedding w JOIN spend s USING (wedding_id)`],
  ['View: budget status', `SELECT * FROM vw_budget_status`],
  ['Set operation: UNION of all contacts', `SELECT vendor_name AS name, phone, 'Vendor' AS type FROM vendor\nUNION SELECT caterer_name, phone, 'Caterer' FROM caterer\nUNION SELECT full_name, phone, 'Planner' FROM planner`],
  ['EXPLAIN: index usage', `EXPLAIN SELECT * FROM guest WHERE full_name = 'Pooja Verma'`],
  ['Meal preference count for caterer', `SELECT meal_preference, COUNT(*) AS guests, SUM(plus_ones) AS extra_plates FROM guest GROUP BY meal_preference`],
];

const RULES = [
  ['CHECK: venue with negative capacity', 'POST', '/api/venues', { venue_name: 'Bad Hall', venue_type: 'Lawn', city: 'Pune', capacity: -5, price_per_day: 1000 }],
  ['TRIGGER: event guests exceed venue capacity', 'POST', '/api/events', { wedding_id: 4, venue_id: 7, event_type: 'Reception', event_date: '2027-01-23', start_time: '19:00', end_time: '23:00', expected_guests: 2000 }],
  ['UNIQUE: venue already booked on that date', 'POST', '/api/events', { wedding_id: 2, venue_id: 1, event_type: 'Haldi', event_date: '2026-12-03', start_time: '10:00', end_time: '12:00', expected_guests: 50 }],
  ['TIME CHECK: event ends before it starts', 'POST', '/api/events', { wedding_id: 4, venue_id: 6, event_type: 'Haldi', event_date: '2027-01-20', start_time: '15:00', end_time: '10:00', expected_guests: 50 }],
  ['PROCEDURE + TRIGGER: payment above budget', 'POST', '/api/payments', { wedding_id: 5, amount: 600000, mode: 'Cash', paid_towards: 'Other', reference_no: 'LAB-1' }],
  ['TRIGGER + TRANSACTION: dish from another caterer', 'PUT', '/api/orders/1/menu', { item_ids: [1, 8] }],
  ['FOREIGN KEY: guest for a wedding that does not exist', 'POST', '/api/guests', { wedding_id: 999, full_name: 'Ghost Guest', side: 'Bride' }],
  ['ON DELETE RESTRICT: delete a venue that has events', 'DELETE', '/api/venues/1', null],
  ['UNIQUE: duplicate phone number for a planner', 'POST', '/api/planners', { full_name: 'Duplicate', phone: '9890011001' }],
];

async function pageLab(sub) {
  setNav('lab');
  const subs = [['schema', 'Schema & Objects'], ['console', 'SQL Console'], ['rules', 'Try the Rules'], ['audit', 'Audit Log']];
  view.innerHTML = `<div class="page-head"><div><h1>DBMS Lab</h1><p>Look inside the database: tables, keys, triggers, procedures - and try to break the rules.</p></div></div>
    <div class="tabs">${subs.map(([k, l]) => `<a href="#/lab/${k}" class="${k === sub ? 'active' : ''}">${l}</a>`).join('')}</div><div id="tabbox"></div>`;
  const box = $('#tabbox');
  if (sub === 'schema') {
    const s = await api('GET', '/api/lab/schema');
    const fkOf = {}; s.fks.forEach((f) => (fkOf[`${f.tbl}.${f.col}`] = `${f.ref_tbl}.${f.ref_col}`));
    const tables = {}; s.cols.forEach((c) => (tables[c.tbl] = tables[c.tbl] || []).push(c));
    const baseNames = Object.keys(s.rowCounts);
    const kinds = { TRIGGER: ['T', 'Triggers'], PROCEDURE: ['P', 'Procedures'], FUNCTION: ['F', 'Functions'], VIEW: ['V', 'Views'] };
    box.innerHTML = `<div class="card" style="margin-bottom:16px"><h3>${baseNames.length} tables &middot; ${s.fks.length} foreign keys</h3>
      ${Object.entries(kinds).map(([k, [cls, label]]) => `<div class="small"><b>${label} (${s.objs.filter((o) => o.kind === k).length})</b></div><div class="chips">${s.objs.filter((o) => o.kind === k).map((o) => `<span class="chip ${cls}">${esc(o.name)}</span>`).join('')}</div>`).join('')}</div>
      <div class="schema-grid">${baseNames.map((t) => `<div class="tbl-card"><h4>${t}<span style="font-size:.7rem;opacity:.8">${s.rowCounts[t]} rows</span></h4>${tables[t].map((c) => {
        const fk = fkOf[`${t}.${c.col}`];
        return `<div class="c"><span>${c.ckey === 'PRI' ? '<span class="pk">&#128273;</span> ' : ''}${fk ? '<span class="fk">&#8599;</span> ' : ''}${esc(c.col)}${fk ? `<span class="t"> &rarr; ${esc(fk)}</span>` : ''}</span><span class="t">${esc(c.type)}</span></div>`;
      }).join('')}</div>`).join('')}</div>`;
  } else if (sub === 'console') {
    box.innerHTML = `<div class="card"><div class="toolbar"><select id="smp" style="max-width:420px"><option value="">-- load a sample query --</option>${SAMPLES.map((s, i) => `<option value="${i}">${esc(s[0])}</option>`).join('')}</select>
      <span class="hint">Read-only console (SELECT / EXPLAIN / SHOW / DESCRIBE)</span></div>
      <textarea class="sql" id="sql" spellcheck="false">SELECT * FROM vw_wedding_overview</textarea>
      <div style="margin:10px 0"><button class="btn" id="run">&#9654; Run query</button> <span class="small" id="stat"></span></div><div id="res"></div></div>`;
    $('#smp').onchange = (e) => { if (e.target.value !== '') $('#sql').value = SAMPLES[e.target.value][1]; };
    const run = async () => {
      try {
        const r = await api('POST', '/api/lab/query', { sql: $('#sql').value });
        $('#stat').textContent = `${r.total} row(s) in ${r.ms} ms`;
        $('#res').innerHTML = `<div class="tbl-wrap"><table><thead><tr>${r.columns.map((c) => `<th>${esc(c)}</th>`).join('')}</tr></thead><tbody>${r.rows.map((row) => `<tr>${row.map((v) => `<td>${esc(v === null ? 'NULL' : v)}</td>`).join('')}</tr>`).join('') || '<tr><td class="empty">No rows</td></tr>'}</tbody></table></div>`;
      } catch (e) { $('#stat').textContent = ''; $('#res').innerHTML = `<div class="err">&#9888; ${esc(e.message)}</div>`; }
    };
    $('#run').onclick = run;
    $('#sql').addEventListener('keydown', (e) => { if (e.ctrlKey && e.key === 'Enter') run(); });
    run();
  } else if (sub === 'rules') {
    box.innerHTML = `<div class="grid g-2"><div class="card"><h3>Break a rule</h3><p class="small">Each button sends a bad request. The error you see is produced by MySQL itself (constraint, trigger or procedure), not by the web app. No data is changed.</p>
      ${RULES.map((r, i) => `<button class="btn ghost trybtn" data-i="${i}">${esc(r[0])}</button>`).join('')}</div>
      <div class="card"><h3>MySQL says...</h3><div id="rout" class="small">Click a rule on the left.</div></div></div>`;
    box.onclick = async (e) => {
      const b = e.target.closest('[data-i]'); if (!b) return;
      const [name, method, url, body] = RULES[b.dataset.i];
      try { await api(method, url, body); $('#rout').innerHTML = `<div class="result-box ok">Unexpectedly succeeded: ${esc(name)}</div>`; }
      catch (err) { $('#rout').innerHTML = `<b>${esc(name)}</b><div class="result-box">&#10060; ${esc(err.message)}</div>`; }
    };
  } else {
    const rows = await api('GET', '/api/lab/audit');
    box.innerHTML = `<p class="small">Rows are written automatically by triggers on <code>wedding</code> and <code>guest</code>. Add a guest or change a wedding status and refresh.</p>
      <div class="tbl-wrap"><table><thead><tr><th>#</th><th>When</th><th>Table</th><th>Action</th><th>Record</th><th>Details</th><th>User</th></tr></thead><tbody>
      ${rows.map((a) => `<tr><td>${a.log_id}</td><td>${esc(a.logged_at)}</td><td>${esc(a.table_name)}</td><td>${badge(a.action)}</td><td>${a.record_id ?? ''}</td><td>${esc(a.details)}</td><td class="small">${esc(a.done_by)}</td></tr>`).join('') || '<tr><td colspan="7" class="empty">Audit log is empty</td></tr>'}</tbody></table></div>`;
  }
}

/* ---------- router ---------- */
async function route() {
  const parts = (location.hash || '#/dashboard').slice(2).split('/');
  view.innerHTML = '<div class="empty">Loading...</div>';
  try {
    if (parts[0] === 'dashboard') await pageDashboard();
    else if (parts[0] === 'weddings') await pageWeddings();
    else if (parts[0] === 'wedding') await pageWedding(parts[1], parts[2] || 'overview');
    else if (parts[0] === 'directory' && DIR[parts[1]]) await pageDirectory(parts[1]);
    else if (parts[0] === 'lab') await pageLab(parts[1] || 'schema');
    else await pageDashboard();
  } catch (e) {
    view.innerHTML = `<div class="card"><h2>Something went wrong</h2><div class="err">${esc(e.message)}</div><p class="small">Check that MySQL is running and the credentials in the .env file are correct.</p></div>`;
  }
}
window.addEventListener('hashchange', route);
route();
