-- =====================================================================
--  File 04 : DBMS CONCEPT DEMONSTRATION QUERIES
--  Each query is numbered and labelled with the concept it shows,
--  so it can be run one-by-one during the lab viva / demo.
--  (Section 12 contains statements that are SUPPOSED to raise errors.)
-- =====================================================================
SET NAMES utf8mb4;
USE wedding_db;

-- =====================================================================
-- 1. DDL : ALTER / TRUNCATE / DROP (on a scratch table, not project data)
-- =====================================================================
-- Q1. CREATE, ALTER (add / modify / drop column, rename) and DROP
CREATE TABLE demo_table (id INT PRIMARY KEY, note VARCHAR(30));
ALTER TABLE demo_table ADD COLUMN created_on DATE;
ALTER TABLE demo_table MODIFY COLUMN note VARCHAR(100) NOT NULL;
ALTER TABLE demo_table RENAME COLUMN note TO remarks;
ALTER TABLE demo_table DROP COLUMN created_on;
DESCRIBE demo_table;
DROP TABLE demo_table;

-- Q2. ALTER on a real table: add a column to GUEST, then remove it again
ALTER TABLE guest ADD COLUMN is_vip BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE guest SET is_vip = TRUE WHERE relation IN ('Father','Mother');
SELECT full_name, relation, is_vip FROM guest WHERE is_vip = TRUE;
ALTER TABLE guest DROP COLUMN is_vip;

-- =====================================================================
-- 2. DML : INSERT / UPDATE / DELETE  (inside a transaction, rolled back)
-- =====================================================================
START TRANSACTION;
-- Q3. INSERT a new vendor
INSERT INTO vendor (vendor_name, service_type, phone, city, base_price, rating)
VALUES ('Sur Taal Live Band', 'DJ & Music', '9833300099', 'Pune', 28000, 4.4);
-- Q4. UPDATE with expression: 10% discount on every Photography vendor
UPDATE vendor SET base_price = base_price * 0.90 WHERE service_type = 'Photography';
-- Q5. DELETE with condition
DELETE FROM vendor WHERE vendor_name = 'Sur Taal Live Band';
SELECT vendor_name, base_price FROM vendor WHERE service_type = 'Photography';
ROLLBACK;     -- undo everything above

-- =====================================================================
-- 3. SELECT BASICS : WHERE, LIKE, IN, BETWEEN, IS NULL, DISTINCT, ORDER BY, LIMIT
-- =====================================================================
-- Q6. Weddings of 2026 sorted by date
SELECT wedding_id, theme, wedding_date, total_budget
FROM wedding
WHERE wedding_date BETWEEN '2026-01-01' AND '2026-12-31'
ORDER BY wedding_date;

-- Q7. Pattern matching: guests whose name starts with 'S' or contains 'ar'
SELECT full_name, city FROM guest WHERE full_name LIKE 'S%' OR full_name LIKE '%ar%';

-- Q8. IN / NOT IN and DISTINCT
SELECT DISTINCT city FROM guest WHERE city IN ('Pune','Mumbai','Kolhapur') ORDER BY city;

-- Q9. NULL handling: guests who have not given an e-mail
SELECT full_name, IFNULL(email,'-- not given --') AS email FROM guest WHERE email IS NULL LIMIT 5;

-- Q10. Top 3 most expensive venues (ORDER BY + LIMIT)
SELECT venue_name, city, price_per_day FROM venue ORDER BY price_per_day DESC LIMIT 3;

-- Q11. Computed columns, aliases and CASE expression
SELECT venue_name, capacity,
       CASE WHEN capacity >= 1000 THEN 'Grand'
            WHEN capacity >= 500  THEN 'Large'
            ELSE 'Intimate' END AS venue_size
FROM venue ORDER BY capacity DESC;

-- =====================================================================
-- 4. BUILT-IN FUNCTIONS : string, date, numeric
-- =====================================================================
-- Q12. Days left for each upcoming wedding (DATEDIFF, CURDATE, DATE_FORMAT)
SELECT CONCAT(c.bride_name,' & ',c.groom_name) AS couple,
       DATE_FORMAT(w.wedding_date,'%d %M %Y (%W)') AS wedding_day,
       DATEDIFF(w.wedding_date, CURDATE()) AS days_left
FROM wedding w JOIN client c USING (client_id)
WHERE w.status IN ('Planning','Confirmed')
ORDER BY w.wedding_date;

-- Q13. String functions
SELECT UPPER(full_name) AS name_upper, LENGTH(full_name) AS name_len,
       SUBSTRING_INDEX(full_name,' ',-1) AS surname
FROM guest LIMIT 5;

-- =====================================================================
-- 5. AGGREGATE FUNCTIONS, GROUP BY, HAVING
-- =====================================================================
-- Q14. Guest count per wedding, split by side
SELECT wedding_id,
       COUNT(*)                     AS total_guests,
       SUM(side = 'Bride')          AS bride_side,
       SUM(side = 'Groom')          AS groom_side,
       SUM(plus_ones) + COUNT(*)    AS headcount_with_plus_ones
FROM guest GROUP BY wedding_id;

-- Q15. HAVING: weddings with more than 8 guests
SELECT wedding_id, COUNT(*) AS guests FROM guest GROUP BY wedding_id HAVING COUNT(*) > 8;

-- Q16. Meal preference count (for the caterer)
SELECT meal_preference, COUNT(*) AS guests, SUM(plus_ones) AS extra_plates
FROM guest GROUP BY meal_preference ORDER BY guests DESC;

-- Q17. MIN / MAX / AVG / SUM on venues per city
SELECT city, COUNT(*) AS venues, MIN(price_per_day) AS cheapest, MAX(price_per_day) AS costliest,
       ROUND(AVG(price_per_day),2) AS avg_price, SUM(capacity) AS total_capacity
FROM venue GROUP BY city ORDER BY venues DESC;

-- Q18. Payments received by mode (GROUP BY on ENUM) with ROLLUP total
SELECT IFNULL(mode,'TOTAL') AS mode, SUM(amount) AS received
FROM payment GROUP BY mode WITH ROLLUP;

-- =====================================================================
-- 6. JOINS
-- =====================================================================
-- Q19. INNER JOIN (3 tables): event schedule with couple and venue
SELECT CONCAT(c.bride_name,' & ',c.groom_name) AS couple, e.event_type, e.event_date, v.venue_name
FROM event e
JOIN wedding w ON w.wedding_id = e.wedding_id
JOIN client  c ON c.client_id  = w.client_id
JOIN venue   v ON v.venue_id   = e.venue_id
ORDER BY e.event_date;

-- Q20. LEFT JOIN: all planners, even those with no wedding
SELECT p.full_name AS planner, COUNT(w.wedding_id) AS weddings_handled
FROM planner p LEFT JOIN wedding w ON w.planner_id = p.planner_id
GROUP BY p.planner_id, p.full_name;

-- Q21. LEFT JOIN + IS NULL (anti-join): venues that have never been booked
SELECT v.venue_name, v.city
FROM venue v LEFT JOIN event e ON e.venue_id = v.venue_id
WHERE e.event_id IS NULL;

-- Q22. RIGHT JOIN: every wedding with its payments (weddings with no payment appear as NULL)
SELECT w.wedding_id, p.payment_id, p.amount
FROM payment p RIGHT JOIN wedding w ON w.wedding_id = p.wedding_id
ORDER BY w.wedding_id;

-- Q23. SELF JOIN: pairs of guests of the same wedding living in the same city
SELECT a.wedding_id, a.full_name AS guest_1, b.full_name AS guest_2, a.city
FROM guest a JOIN guest b
  ON a.wedding_id = b.wedding_id AND a.city = b.city AND a.guest_id < b.guest_id
ORDER BY a.wedding_id, a.city;

-- Q24. M:N join through junction table: which events is each guest of wedding 1 invited to?
SELECT g.full_name, e.event_type, i.rsvp_status
FROM guest g
JOIN invitation i ON i.guest_id = g.guest_id
JOIN event e      ON e.event_id = i.event_id
WHERE g.wedding_id = 1
ORDER BY g.full_name, e.event_date;

-- Q25. Full menu of a catering order (M:N: order <-> menu_item)
SELECT co.order_id, ct.caterer_name, e.event_type, mi.course, mi.item_name, mi.price_per_plate
FROM catering_order co
JOIN caterer ct    ON ct.caterer_id = co.caterer_id
JOIN event e       ON e.event_id    = co.event_id
JOIN order_item oi ON oi.order_id   = co.order_id
JOIN menu_item mi  ON mi.item_id    = oi.item_id
WHERE co.order_id = 2
ORDER BY FIELD(mi.course,'Welcome Drink','Starter','Main Course','Bread','Rice','Dessert','Beverage');

-- Q26. CROSS JOIN: all possible (caterer, course) combinations
SELECT c.caterer_name, cr.course
FROM caterer c
CROSS JOIN (SELECT DISTINCT course FROM menu_item) cr
LIMIT 8;

-- =====================================================================
-- 7. SUBQUERIES
-- =====================================================================
-- Q27. Scalar subquery: venues costlier than the average venue
SELECT venue_name, price_per_day FROM venue
WHERE price_per_day > (SELECT AVG(price_per_day) FROM venue);

-- Q28. IN subquery: clients who have at least one Confirmed wedding
SELECT bride_name, groom_name FROM client
WHERE client_id IN (SELECT client_id FROM wedding WHERE status = 'Confirmed');

-- Q29. EXISTS: weddings that have at least one Pending RSVP
SELECT w.wedding_id, w.theme FROM wedding w
WHERE EXISTS (SELECT 1 FROM guest g JOIN invitation i ON i.guest_id = g.guest_id
              WHERE g.wedding_id = w.wedding_id AND i.rsvp_status = 'Pending');

-- Q30. NOT EXISTS: guests who were invited to nothing
SELECT g.full_name FROM guest g
WHERE NOT EXISTS (SELECT 1 FROM invitation i WHERE i.guest_id = g.guest_id);

-- Q31. Correlated subquery: guests whose plus-ones exceed the average of their own wedding
SELECT g.full_name, g.wedding_id, g.plus_ones FROM guest g
WHERE g.plus_ones > (SELECT AVG(g2.plus_ones) FROM guest g2 WHERE g2.wedding_id = g.wedding_id);

-- Q32. ALL / ANY: vendors costlier than ALL Florist vendors
SELECT vendor_name, service_type, base_price FROM vendor
WHERE base_price > ALL (SELECT base_price FROM vendor WHERE service_type = 'Florist');

-- Q33. Subquery in FROM (derived table): wedding with the highest total payments
SELECT t.wedding_id, t.paid
FROM (SELECT wedding_id, SUM(amount) AS paid FROM payment GROUP BY wedding_id) t
ORDER BY t.paid DESC LIMIT 1;

-- =====================================================================
-- 8. SET OPERATIONS  (INTERSECT / EXCEPT need MySQL 8.0.31+)
-- =====================================================================
-- Q34. UNION: one contact list of all service providers
SELECT vendor_name AS name, phone, 'Vendor'  AS type FROM vendor
UNION
SELECT caterer_name, phone, 'Caterer' FROM caterer
UNION
SELECT full_name, phone, 'Planner' FROM planner
ORDER BY type, name;

-- Q35. INTERSECT: cities that have both a venue and a caterer
SELECT city FROM venue INTERSECT SELECT city FROM caterer;

-- Q36. EXCEPT: cities that have a venue but no caterer
SELECT city FROM venue EXCEPT SELECT city FROM caterer;

-- =====================================================================
-- 9. ADVANCED SQL : CTE, WINDOW FUNCTIONS
-- =====================================================================
-- Q37. CTE: spend per wedding vs budget
WITH spend AS (
    SELECT wedding_id, fn_total_expense(wedding_id) AS expense FROM wedding
)
SELECT w.wedding_id, w.total_budget, s.expense,
       ROUND(s.expense / w.total_budget * 100, 1) AS pct_of_budget_used
FROM wedding w JOIN spend s USING (wedding_id)
ORDER BY pct_of_budget_used DESC;

-- Q38. RANK() window function: vendors ranked by rating inside each service type
SELECT service_type, vendor_name, rating,
       RANK() OVER (PARTITION BY service_type ORDER BY rating DESC) AS rank_in_service
FROM vendor;

-- Q39. Running total of payments per wedding (SUM OVER)
SELECT wedding_id, payment_date, amount,
       SUM(amount) OVER (PARTITION BY wedding_id ORDER BY payment_date, payment_id) AS running_total
FROM payment;

-- Q40. ROW_NUMBER + LAG: each payment and the gap in days from the previous one
SELECT wedding_id, payment_date,
       ROW_NUMBER() OVER (PARTITION BY wedding_id ORDER BY payment_date) AS installment_no,
       DATEDIFF(payment_date, LAG(payment_date) OVER (PARTITION BY wedding_id ORDER BY payment_date)) AS days_since_prev
FROM payment;

-- =====================================================================
-- 10. USING VIEWS, FUNCTIONS and PROCEDURES
-- =====================================================================
-- Q41. Views (virtual tables)
SELECT * FROM vw_wedding_overview;
SELECT * FROM vw_budget_status;
SELECT * FROM vw_guest_rsvp_summary WHERE wedding_id = 1;
SELECT * FROM vw_catering_menu_cost;

-- Q42. Calling stored functions
SELECT wedding_id, fn_venue_cost(wedding_id) AS venue, fn_catering_cost(wedding_id) AS catering,
       fn_total_expense(wedding_id) AS total, fn_total_paid(wedding_id) AS paid
FROM wedding;

-- Q43. Calling stored procedures
CALL sp_wedding_summary(1);
CALL sp_assign_tables(3);                        -- CURSOR + LOOP seating chart
SELECT g.full_name, i.table_no FROM invitation i JOIN guest g USING (guest_id)
WHERE i.event_id = 3 AND i.rsvp_status = 'Accepted' ORDER BY i.table_no, g.full_name;

CALL sp_add_payment(4, 50000, 'UPI', 'Venue', 'TXN-4002', @msg);       -- OUT parameter
SELECT @msg AS procedure_result;
CALL sp_add_payment(4, 99999999, 'UPI', 'Venue', 'TXN-4003', @msg);    -- exceeds budget -> ROLLBACK
SELECT @msg AS procedure_result;

CALL sp_book_vendor(10, 1, 45000, @msg);   SELECT @msg AS procedure_result;
CALL sp_book_vendor(10, 1, 45000, @msg);   SELECT @msg AS procedure_result;   -- duplicate -> fails

-- =====================================================================
-- 11. TRANSACTIONS : ACID, COMMIT, ROLLBACK, SAVEPOINT
-- =====================================================================
-- Q44. Atomicity: re-label a payment and change an amount, then undo (SAVEPOINT + ROLLBACK)
START TRANSACTION;
    UPDATE payment SET paid_towards = 'Venue' WHERE payment_id = 1;
    SAVEPOINT after_first_update;
    UPDATE payment SET amount = amount + 1000 WHERE payment_id = 2;
    SELECT payment_id, paid_towards, amount FROM payment WHERE payment_id IN (1,2);
    ROLLBACK TO after_first_update;        -- undo only the second update
    SELECT payment_id, paid_towards, amount FROM payment WHERE payment_id IN (1,2);
ROLLBACK;                                  -- undo everything
SELECT payment_id, paid_towards, amount FROM payment WHERE payment_id IN (1,2);

-- Q45. Cancel a wedding atomically with a procedure (it has its own COMMIT, so we use a
--      throw-away wedding and delete it afterwards instead of rolling back)
INSERT INTO client (bride_name, groom_name, phone, city) VALUES ('Temp Bride','Temp Groom','9000000002','Pune');
SET @temp_client = LAST_INSERT_ID();
INSERT INTO wedding (client_id, planner_id, wedding_date, theme, total_budget) VALUES (@temp_client, 1, '2027-04-01', 'Temp', 100000);
SET @temp_wedding = LAST_INSERT_ID();
CALL sp_cancel_wedding(@temp_wedding);
SELECT wedding_id, status FROM wedding WHERE wedding_id = @temp_wedding;
SELECT status, COUNT(*) AS tasks FROM task WHERE wedding_id = @temp_wedding GROUP BY status;
SELECT * FROM audit_log ORDER BY log_id DESC LIMIT 3;
DELETE FROM client WHERE client_id = @temp_client;       -- clean-up (cascades to wedding and tasks)

-- =====================================================================
-- 12. CONSTRAINTS & TRIGGERS IN ACTION  (each statement below SHOULD FAIL)
--     Run them one at a time. Error text is shown in the comment.
-- =====================================================================
-- Q46. CHECK constraint violated
-- INSERT INTO venue (venue_name, venue_type, city, capacity, price_per_day) VALUES ('Bad Hall','Lawn','Pune',-5,1000);
--   ERROR 3819: Check constraint 'chk_venue_capacity' is violated.
-- Q47. UNIQUE constraint violated (venue already booked that day)
-- INSERT INTO event (wedding_id, venue_id, event_type, event_date, start_time, end_time, expected_guests)
-- VALUES (2, 1, 'Haldi', '2026-12-03', '10:00', '12:00', 50);
--   ERROR 1062: Duplicate entry ... for key 'uq_venue_per_day'
-- Q48. FOREIGN KEY violated (wedding 999 does not exist)
-- INSERT INTO guest (wedding_id, full_name, side) VALUES (999, 'Ghost Guest', 'Bride');
--   ERROR 1452: Cannot add or update a child row: a foreign key constraint fails
-- Q49. ON DELETE RESTRICT: cannot delete a venue that hosts events
-- DELETE FROM venue WHERE venue_id = 1;
--   ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails
-- Q50. NOT NULL violated
-- INSERT INTO client (bride_name, groom_name, phone) VALUES (NULL, 'X', '9999999999');
--   ERROR 1048: Column 'bride_name' cannot be null
-- Q51. TRIGGER: expected guests exceed venue capacity
-- INSERT INTO event (wedding_id, venue_id, event_type, event_date, start_time, end_time, expected_guests)
-- VALUES (4, 7, 'Reception', '2027-01-23', '19:00', '23:00', 2000);
--   ERROR 1644: Expected guests exceed the capacity of the selected venue
-- Q52. TRIGGER: menu item from a different caterer
-- INSERT INTO order_item (order_id, item_id) VALUES (1, 8);
--   ERROR 1644: Menu item does not belong to the caterer of this order
-- Q53. TRIGGER: payment above budget
-- INSERT INTO payment (wedding_id, amount, mode, paid_towards, reference_no) VALUES (5, 600000, 'Cash', 'Other', 'X-1');
--   ERROR 1644: Payment rejected: total payments would exceed the wedding budget

-- =====================================================================
-- 13. TRIGGERS THAT SUCCEED : automatic task list + audit log
-- =====================================================================
START TRANSACTION;
-- Q54. A new wedding automatically gets 6 checklist tasks (trg_wedding_after_insert)
INSERT INTO client (bride_name, groom_name, phone, city) VALUES ('Test Bride','Test Groom','9000000001','Pune');
INSERT INTO wedding (client_id, planner_id, wedding_date, theme, total_budget)
VALUES (LAST_INSERT_ID(), 1, '2027-03-01', 'Demo Theme', 400000);
SELECT title, category, due_date, priority FROM task WHERE wedding_id = LAST_INSERT_ID();

-- Q55. Status change is written to audit_log (trg_wedding_after_update)
UPDATE wedding SET status = 'Confirmed' WHERE wedding_id = LAST_INSERT_ID();
SELECT table_name, action, details FROM audit_log ORDER BY log_id DESC LIMIT 3;

-- Q56. RSVP update stamps responded_on automatically (trg_invitation_before_update)
UPDATE invitation SET rsvp_status = 'Accepted' WHERE guest_id = 8 AND event_id = 3;
SELECT guest_id, event_id, rsvp_status, responded_on FROM invitation WHERE guest_id = 8 AND event_id = 3;
ROLLBACK;

-- =====================================================================
-- 14. CASCADE DELETE DEMO  (ON DELETE CASCADE) - rolled back afterwards
-- =====================================================================
START TRANSACTION;
SELECT (SELECT COUNT(*) FROM guest      WHERE wedding_id = 2) AS guests_before,
       (SELECT COUNT(*) FROM event      WHERE wedding_id = 2) AS events_before,
       (SELECT COUNT(*) FROM payment    WHERE wedding_id = 2) AS payments_before;
DELETE FROM wedding WHERE wedding_id = 2;       -- children vanish automatically
SELECT (SELECT COUNT(*) FROM guest      WHERE wedding_id = 2) AS guests_after,
       (SELECT COUNT(*) FROM event      WHERE wedding_id = 2) AS events_after,
       (SELECT COUNT(*) FROM payment    WHERE wedding_id = 2) AS payments_after;
ROLLBACK;

-- =====================================================================
-- 15. INDEXES & QUERY OPTIMISATION (EXPLAIN)
-- =====================================================================
-- Q57. Search by guest name uses idx_guest_name (type = range/ref instead of ALL)
EXPLAIN SELECT * FROM guest WHERE full_name = 'Pooja Verma';
-- Q58. Same query without index usage (LIKE with leading wildcard -> full table scan)
EXPLAIN SELECT * FROM guest WHERE full_name LIKE '%Verma';
SHOW INDEX FROM guest;

-- =====================================================================
-- 16. REPORTS - useful real-life queries for the application
-- =====================================================================
-- Q59. Remaining budget and payment status for every wedding
SELECT couple, total_budget, total_expense, budget_remaining, amount_paid, balance_due,
       IF(budget_remaining < 0, 'OVER BUDGET', 'Within budget') AS budget_flag
FROM vw_budget_status;

-- Q60. RSVP funnel per event: accepted / declined / pending + percentage
SELECT e.event_type, w.wedding_id,
       SUM(i.rsvp_status='Accepted') AS accepted, SUM(i.rsvp_status='Declined') AS declined,
       SUM(i.rsvp_status='Pending') AS pending,
       ROUND(100*SUM(i.rsvp_status='Accepted')/COUNT(*),0) AS accept_pct
FROM event e JOIN wedding w USING (wedding_id)
JOIN invitation i ON i.event_id = e.event_id
GROUP BY e.event_id, e.event_type, w.wedding_id;

-- Q61. Plates required per event = accepted guests + their plus-ones
SELECT e.event_id, e.event_type, COUNT(*) + SUM(g.plus_ones) AS plates_needed, co.no_of_plates AS plates_ordered
FROM event e
JOIN invitation i ON i.event_id = e.event_id AND i.rsvp_status = 'Accepted'
JOIN guest g ON g.guest_id = i.guest_id
LEFT JOIN catering_order co ON co.event_id = e.event_id
GROUP BY e.event_id, e.event_type, co.no_of_plates;

-- Q62. Vendors booked per wedding with total spend per service type
SELECT w.wedding_id, v.service_type, COUNT(*) AS bookings, SUM(vb.agreed_price) AS spend
FROM vendor_booking vb
JOIN event e ON e.event_id = vb.event_id JOIN wedding w ON w.wedding_id = e.wedding_id
JOIN vendor v ON v.vendor_id = vb.vendor_id
WHERE vb.booking_status <> 'Cancelled'
GROUP BY w.wedding_id, v.service_type WITH ROLLUP;

-- Q63. Outstation guests (city differs from the couple's city) who need rooms
SELECT g.full_name, g.city AS guest_city, c.city AS couple_city, IF(rb.room_booking_id IS NULL,'NO ROOM','Booked') AS accommodation
FROM guest g
JOIN wedding w ON w.wedding_id = g.wedding_id
JOIN client c  ON c.client_id  = w.client_id
LEFT JOIN room_booking rb ON rb.guest_id = g.guest_id
WHERE g.city <> c.city AND g.wedding_id = 1;

-- Q64. Pending checklist items due in the next 30 days relative to a reference date
SELECT w.wedding_id, t.title, t.due_date, t.priority
FROM task t JOIN wedding w USING (wedding_id)
WHERE t.status <> 'Done' AND t.due_date BETWEEN '2026-10-15' AND DATE_ADD('2026-10-15', INTERVAL 30 DAY)
ORDER BY t.due_date;

-- Q65. Gifts received and thank-you notes still pending
SELECT g.full_name, gf.gift_type, gf.estimated_value
FROM gift gf JOIN guest g USING (guest_id) WHERE gf.thank_you_sent = FALSE;
