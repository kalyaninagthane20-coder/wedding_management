-- =====================================================================
--  File 03 : Views, Stored Functions, Stored Procedures, Triggers
--
--  DBMS concepts shown here:
--   * VIEWS (simple, join, aggregate) - virtual tables / data abstraction
--   * STORED FUNCTIONS - reusable calculations
--   * STORED PROCEDURES - IN/OUT params, IF, transactions (START TRANSACTION,
--     COMMIT, ROLLBACK), exception HANDLER, CURSOR, LOOP
--   * TRIGGERS - BEFORE/AFTER INSERT/UPDATE/DELETE, SIGNAL for business rules,
--     automatic audit logging
-- Run with the mysql command-line client (it understands DELIMITER).
-- =====================================================================
SET NAMES utf8mb4;
USE wedding_db;

-- =====================================================================
--  A. STORED FUNCTIONS
-- =====================================================================
DROP FUNCTION IF EXISTS fn_total_paid;
DROP FUNCTION IF EXISTS fn_venue_cost;
DROP FUNCTION IF EXISTS fn_catering_cost;
DROP FUNCTION IF EXISTS fn_vendor_cost;
DROP FUNCTION IF EXISTS fn_accommodation_cost;
DROP FUNCTION IF EXISTS fn_transport_cost;
DROP FUNCTION IF EXISTS fn_total_expense;

DELIMITER $$

CREATE FUNCTION fn_total_paid(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(amount),0) FROM payment WHERE wedding_id = p_wedding);
END$$

CREATE FUNCTION fn_venue_cost(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(v.price_per_day),0)
            FROM event e JOIN venue v ON v.venue_id = e.venue_id
            WHERE e.wedding_id = p_wedding);
END$$

-- plates x (sum of price of the items chosen in that order)
CREATE FUNCTION fn_catering_cost(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(co.no_of_plates * x.plate_rate),0)
            FROM catering_order co
            JOIN event e ON e.event_id = co.event_id
            JOIN (SELECT oi.order_id, SUM(mi.price_per_plate) AS plate_rate
                  FROM order_item oi JOIN menu_item mi ON mi.item_id = oi.item_id
                  GROUP BY oi.order_id) x ON x.order_id = co.order_id
            WHERE e.wedding_id = p_wedding AND co.order_status <> 'Cancelled');
END$$

CREATE FUNCTION fn_vendor_cost(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(vb.agreed_price),0)
            FROM vendor_booking vb JOIN event e ON e.event_id = vb.event_id
            WHERE e.wedding_id = p_wedding AND vb.booking_status <> 'Cancelled');
END$$

CREATE FUNCTION fn_accommodation_cost(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(rb.rooms * DATEDIFF(rb.check_out, rb.check_in) * h.price_per_night),0)
            FROM room_booking rb
            JOIN guest g ON g.guest_id = rb.guest_id
            JOIN hotel h ON h.hotel_id = rb.hotel_id
            WHERE g.wedding_id = p_wedding);
END$$

CREATE FUNCTION fn_transport_cost(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    RETURN (SELECT IFNULL(SUM(vehicle_count * cost_per_vehicle),0)
            FROM transport WHERE wedding_id = p_wedding);
END$$

CREATE FUNCTION fn_total_expense(p_wedding INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_fee DECIMAL(10,2);
    SELECT IFNULL(pl.fee,0) INTO v_fee
    FROM wedding w LEFT JOIN planner pl ON pl.planner_id = w.planner_id
    WHERE w.wedding_id = p_wedding;
    RETURN IFNULL(v_fee,0) + fn_venue_cost(p_wedding) + fn_catering_cost(p_wedding)
         + fn_vendor_cost(p_wedding) + fn_accommodation_cost(p_wedding)
         + fn_transport_cost(p_wedding);
END$$

DELIMITER ;

-- =====================================================================
--  B. VIEWS
-- =====================================================================
CREATE OR REPLACE VIEW vw_wedding_overview AS
SELECT w.wedding_id,
       CONCAT(c.bride_name, ' & ', c.groom_name) AS couple,
       c.city AS client_city,
       w.wedding_date, w.theme, w.status, w.total_budget,
       IFNULL(p.full_name,'Not assigned') AS planner,
       (SELECT COUNT(*) FROM event e WHERE e.wedding_id = w.wedding_id) AS no_of_events,
       (SELECT COUNT(*) FROM guest g WHERE g.wedding_id = w.wedding_id) AS no_of_guests
FROM wedding w
JOIN client c ON c.client_id = w.client_id
LEFT JOIN planner p ON p.planner_id = w.planner_id;

CREATE OR REPLACE VIEW vw_event_schedule AS
SELECT e.event_id, w.wedding_id,
       CONCAT(c.bride_name, ' & ', c.groom_name) AS couple,
       e.event_type, e.event_date, e.start_time, e.end_time,
       v.venue_name, v.city AS venue_city, v.capacity, e.expected_guests,
       ROUND(e.expected_guests / v.capacity * 100, 1) AS capacity_used_pct
FROM event e
JOIN wedding w ON w.wedding_id = e.wedding_id
JOIN client  c ON c.client_id  = w.client_id
JOIN venue   v ON v.venue_id   = e.venue_id;

CREATE OR REPLACE VIEW vw_guest_rsvp_summary AS
SELECT g.wedding_id, g.guest_id, g.full_name, g.side, g.meal_preference, g.plus_ones,
       SUM(i.rsvp_status = 'Accepted') AS accepted,
       SUM(i.rsvp_status = 'Declined') AS declined,
       SUM(i.rsvp_status = 'Pending')  AS pending,
       COUNT(i.event_id)               AS invited_to
FROM guest g LEFT JOIN invitation i ON i.guest_id = g.guest_id
GROUP BY g.wedding_id, g.guest_id, g.full_name, g.side, g.meal_preference, g.plus_ones;

CREATE OR REPLACE VIEW vw_budget_status AS
SELECT w.wedding_id,
       CONCAT(c.bride_name, ' & ', c.groom_name) AS couple,
       w.total_budget,
       fn_venue_cost(w.wedding_id)         AS venue_cost,
       fn_catering_cost(w.wedding_id)      AS catering_cost,
       fn_vendor_cost(w.wedding_id)        AS vendor_cost,
       fn_accommodation_cost(w.wedding_id) AS accommodation_cost,
       fn_transport_cost(w.wedding_id)     AS transport_cost,
       IFNULL(p.fee,0)                     AS planner_fee,
       fn_total_expense(w.wedding_id)      AS total_expense,
       w.total_budget - fn_total_expense(w.wedding_id) AS budget_remaining,
       fn_total_paid(w.wedding_id)         AS amount_paid,
       fn_total_expense(w.wedding_id) - fn_total_paid(w.wedding_id) AS balance_due
FROM wedding w
JOIN client c ON c.client_id = w.client_id
LEFT JOIN planner p ON p.planner_id = w.planner_id;

CREATE OR REPLACE VIEW vw_catering_menu_cost AS
SELECT co.order_id, e.wedding_id, e.event_type, ct.caterer_name, co.no_of_plates, co.order_status,
       SUM(mi.price_per_plate)                  AS rate_per_plate,
       co.no_of_plates * SUM(mi.price_per_plate) AS order_total
FROM catering_order co
JOIN event e      ON e.event_id   = co.event_id
JOIN caterer ct   ON ct.caterer_id = co.caterer_id
JOIN order_item oi ON oi.order_id = co.order_id
JOIN menu_item mi  ON mi.item_id  = oi.item_id
GROUP BY co.order_id, e.wedding_id, e.event_type, ct.caterer_name, co.no_of_plates, co.order_status;

CREATE OR REPLACE VIEW vw_vendor_directory AS
SELECT v.vendor_id, v.vendor_name, v.service_type, v.city, v.base_price, v.rating,
       COUNT(vb.booking_id) AS times_booked
FROM vendor v LEFT JOIN vendor_booking vb
     ON vb.vendor_id = v.vendor_id AND vb.booking_status <> 'Cancelled'
GROUP BY v.vendor_id, v.vendor_name, v.service_type, v.city, v.base_price, v.rating;

-- =====================================================================
--  C. TRIGGERS
-- =====================================================================
DROP TRIGGER IF EXISTS trg_wedding_after_insert;
DROP TRIGGER IF EXISTS trg_wedding_after_update;
DROP TRIGGER IF EXISTS trg_event_before_insert;
DROP TRIGGER IF EXISTS trg_event_before_update;
DROP TRIGGER IF EXISTS trg_guest_after_insert;
DROP TRIGGER IF EXISTS trg_guest_after_delete;
DROP TRIGGER IF EXISTS trg_payment_before_insert;
DROP TRIGGER IF EXISTS trg_order_item_before_insert;
DROP TRIGGER IF EXISTS trg_invitation_before_update;

DELIMITER $$

-- 1. Every new wedding automatically gets a starter checklist (AFTER INSERT)
CREATE TRIGGER trg_wedding_after_insert
AFTER INSERT ON wedding
FOR EACH ROW
BEGIN
    INSERT INTO task (wedding_id, title, category, due_date, priority) VALUES
      (NEW.wedding_id, 'Finalise venue booking',      'Venue',    DATE_SUB(NEW.wedding_date, INTERVAL 120 DAY), 'High'),
      (NEW.wedding_id, 'Shortlist caterer and tasting','Catering', DATE_SUB(NEW.wedding_date, INTERVAL 90 DAY),  'High'),
      (NEW.wedding_id, 'Prepare guest list',          'Guests',   DATE_SUB(NEW.wedding_date, INTERVAL 80 DAY),  'High'),
      (NEW.wedding_id, 'Book photographer & decorator','Vendors',  DATE_SUB(NEW.wedding_date, INTERVAL 75 DAY),  'Medium'),
      (NEW.wedding_id, 'Send invitations',            'Guests',   DATE_SUB(NEW.wedding_date, INTERVAL 45 DAY),  'Medium'),
      (NEW.wedding_id, 'Confirm pandit and muhurat',  'Rituals',  DATE_SUB(NEW.wedding_date, INTERVAL 30 DAY),  'High');
    INSERT INTO audit_log (table_name, action, record_id, details, done_by)
    VALUES ('wedding','INSERT',NEW.wedding_id,CONCAT('New wedding booked for ',NEW.wedding_date),USER());
END$$

-- 2. Log every status change of a wedding (AFTER UPDATE)
CREATE TRIGGER trg_wedding_after_update
AFTER UPDATE ON wedding
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO audit_log (table_name, action, record_id, details, done_by)
        VALUES ('wedding','UPDATE',NEW.wedding_id,
                CONCAT('Status changed: ', OLD.status, ' -> ', NEW.status), USER());
    END IF;
END$$

-- 3. Business rule: guests cannot exceed venue capacity (BEFORE INSERT / UPDATE)
CREATE TRIGGER trg_event_before_insert
BEFORE INSERT ON event
FOR EACH ROW
BEGIN
    DECLARE v_cap INT;
    SELECT capacity INTO v_cap FROM venue WHERE venue_id = NEW.venue_id;
    IF NEW.expected_guests > v_cap THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expected guests exceed the capacity of the selected venue';
    END IF;
END$$

CREATE TRIGGER trg_event_before_update
BEFORE UPDATE ON event
FOR EACH ROW
BEGIN
    DECLARE v_cap INT;
    SELECT capacity INTO v_cap FROM venue WHERE venue_id = NEW.venue_id;
    IF NEW.expected_guests > v_cap THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Expected guests exceed the capacity of the selected venue';
    END IF;
END$$

-- 4. Audit guest additions / removals
CREATE TRIGGER trg_guest_after_insert
AFTER INSERT ON guest
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, details, done_by)
    VALUES ('guest','INSERT',NEW.guest_id,CONCAT('Guest added: ',NEW.full_name),USER());
END$$

CREATE TRIGGER trg_guest_after_delete
AFTER DELETE ON guest
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, details, done_by)
    VALUES ('guest','DELETE',OLD.guest_id,CONCAT('Guest removed: ',OLD.full_name),USER());
END$$

-- 5. A client cannot pay more than the wedding's total budget
CREATE TRIGGER trg_payment_before_insert
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE v_budget DECIMAL(12,2);
    DECLARE v_paid   DECIMAL(12,2);
    SELECT total_budget INTO v_budget FROM wedding WHERE wedding_id = NEW.wedding_id;
    SELECT IFNULL(SUM(amount),0) INTO v_paid FROM payment WHERE wedding_id = NEW.wedding_id;
    IF v_paid + NEW.amount > v_budget THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment rejected: total payments would exceed the wedding budget';
    END IF;
END$$

-- 6. A menu item must belong to the caterer of the order
CREATE TRIGGER trg_order_item_before_insert
BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    DECLARE v_order_caterer INT;
    DECLARE v_item_caterer  INT;
    SELECT caterer_id INTO v_order_caterer FROM catering_order WHERE order_id = NEW.order_id;
    SELECT caterer_id INTO v_item_caterer  FROM menu_item      WHERE item_id  = NEW.item_id;
    IF v_order_caterer <> v_item_caterer THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Menu item does not belong to the caterer of this order';
    END IF;
END$$

-- 7. Stamp the RSVP response time automatically
CREATE TRIGGER trg_invitation_before_update
BEFORE UPDATE ON invitation
FOR EACH ROW
BEGIN
    IF OLD.rsvp_status <> NEW.rsvp_status THEN
        SET NEW.responded_on = NOW();
        IF NEW.rsvp_status = 'Declined' THEN
            SET NEW.table_no = NULL;
        END IF;
    END IF;
END$$

DELIMITER ;

-- =====================================================================
--  D. STORED PROCEDURES
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_wedding_summary;
DROP PROCEDURE IF EXISTS sp_add_payment;
DROP PROCEDURE IF EXISTS sp_book_vendor;
DROP PROCEDURE IF EXISTS sp_cancel_wedding;
DROP PROCEDURE IF EXISTS sp_assign_tables;

DELIMITER $$

-- 1. Simple procedure with IN parameter returning a result set
CREATE PROCEDURE sp_wedding_summary(IN p_wedding INT)
BEGIN
    SELECT * FROM vw_wedding_overview WHERE wedding_id = p_wedding;
    SELECT * FROM vw_budget_status    WHERE wedding_id = p_wedding;
    SELECT * FROM vw_event_schedule   WHERE wedding_id = p_wedding ORDER BY event_date;
END$$

-- 2. Procedure with OUT parameter + transaction + exception handler
CREATE PROCEDURE sp_add_payment(
    IN  p_wedding INT, IN p_amount DECIMAL(12,2), IN p_mode VARCHAR(20),
    IN  p_towards VARCHAR(20), IN p_ref VARCHAR(40),
    OUT p_message VARCHAR(120))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_text = MESSAGE_TEXT;   -- read MySQL's own error text
        ROLLBACK;
        SET p_message = CONCAT('FAILED: ', @err_text);
    END;

    START TRANSACTION;
        INSERT INTO payment (wedding_id, amount, mode, paid_towards, reference_no)
        VALUES (p_wedding, p_amount, p_mode, p_towards, p_ref);   -- trigger checks budget
    COMMIT;
    SET p_message = CONCAT('SUCCESS: payment recorded. Total paid so far = ', fn_total_paid(p_wedding));
END$$

-- 3. Book a vendor only if the vendor is free on that event date
CREATE PROCEDURE sp_book_vendor(
    IN p_event INT, IN p_vendor INT, IN p_price DECIMAL(10,2), OUT p_message VARCHAR(120))
BEGIN
    DECLARE v_date DATE;
    DECLARE v_clash INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @err_text = MESSAGE_TEXT;
        ROLLBACK;
        SET p_message = CONCAT('FAILED: ', @err_text);
    END;

    SELECT event_date INTO v_date FROM event WHERE event_id = p_event;
    SELECT COUNT(*) INTO v_clash
    FROM vendor_booking vb JOIN event e ON e.event_id = vb.event_id
    WHERE vb.vendor_id = p_vendor AND e.event_date = v_date AND vb.booking_status IN ('Booked','Enquired');

    IF v_clash > 0 THEN
        SET p_message = 'FAILED: vendor is already busy on that date';
    ELSE
        START TRANSACTION;
            INSERT INTO vendor_booking (event_id, vendor_id, agreed_price, booking_status)
            VALUES (p_event, p_vendor, p_price, 'Booked');
        COMMIT;
        SET p_message = 'SUCCESS: vendor booked';
    END IF;
END$$

-- 4. Cancel a wedding: several updates that must succeed or fail TOGETHER (atomicity)
CREATE PROCEDURE sp_cancel_wedding(IN p_wedding INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'FAILED: nothing was changed' AS result;
    END;

    START TRANSACTION;
        UPDATE wedding SET status = 'Cancelled' WHERE wedding_id = p_wedding;

        UPDATE vendor_booking vb JOIN event e ON e.event_id = vb.event_id
        SET vb.booking_status = 'Cancelled'
        WHERE e.wedding_id = p_wedding AND vb.booking_status <> 'Completed';

        UPDATE catering_order co JOIN event e ON e.event_id = co.event_id
        SET co.order_status = 'Cancelled'
        WHERE e.wedding_id = p_wedding AND co.order_status <> 'Served';

        UPDATE task SET status = 'Done' WHERE wedding_id = p_wedding AND status <> 'Done';
    COMMIT;
    SELECT 'SUCCESS: wedding, vendor bookings and catering orders cancelled' AS result;
END$$

-- 5. CURSOR + LOOP: seat accepted guests, 8 per table, per event
CREATE PROCEDURE sp_assign_tables(IN p_event INT)
BEGIN
    DECLARE v_guest INT;
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_done  BOOLEAN DEFAULT FALSE;
    DECLARE cur CURSOR FOR
        SELECT guest_id FROM invitation
        WHERE event_id = p_event AND rsvp_status = 'Accepted'
        ORDER BY guest_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    OPEN cur;
    seat_loop: LOOP
        FETCH cur INTO v_guest;
        IF v_done THEN LEAVE seat_loop; END IF;
        SET v_count = v_count + 1;
        UPDATE invitation SET table_no = CEIL(v_count / 8)
        WHERE event_id = p_event AND guest_id = v_guest;
    END LOOP;
    CLOSE cur;

    SELECT v_count AS guests_seated, CEIL(v_count / 8) AS tables_used;
END$$

DELIMITER ;

-- The audit log should not contain anything from set-up work
-- (nothing to clear: triggers were created after the sample data was loaded).
