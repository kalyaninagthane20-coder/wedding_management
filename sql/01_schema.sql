-- =====================================================================
--  WEDDING MANAGEMENT SYSTEM  -  DBMS MINI PROJECT (MySQL 8.0)
--  File 01 : DDL - Database, Tables, Constraints, Indexes
--
--  DBMS concepts shown in this file:
--   * CREATE DATABASE / CREATE TABLE / DROP
--   * Data types: INT, DECIMAL, VARCHAR, CHAR, DATE, TIME, DATETIME,
--     TIMESTAMP, ENUM, BOOLEAN
--   * Constraints: PRIMARY KEY, composite PRIMARY KEY, FOREIGN KEY,
--     UNIQUE, composite UNIQUE, NOT NULL, DEFAULT, CHECK, AUTO_INCREMENT
--   * Referential actions: ON DELETE CASCADE / SET NULL / RESTRICT
--   * Relationships: 1:1, 1:N and M:N (via junction tables)
--   * Secondary indexes
--   * Schema is in 3NF (see README for the normalization notes)
-- =====================================================================

SET NAMES utf8mb4;
DROP DATABASE IF EXISTS wedding_db;
CREATE DATABASE wedding_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE wedding_db;

-- ---------------------------------------------------------------------
-- 1. PLANNER : wedding planners working for the company
-- ---------------------------------------------------------------------
CREATE TABLE planner (
    planner_id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name         VARCHAR(100)  NOT NULL,
    phone             CHAR(10)      NOT NULL UNIQUE,
    email             VARCHAR(100)  UNIQUE,
    experience_years  TINYINT UNSIGNED NOT NULL DEFAULT 0,
    fee               DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT chk_planner_phone CHECK (CHAR_LENGTH(phone) = 10),
    CONSTRAINT chk_planner_fee   CHECK (fee >= 0)
);

-- ---------------------------------------------------------------------
-- 2. CLIENT : the couple who books the wedding
-- ---------------------------------------------------------------------
CREATE TABLE client (
    client_id      INT AUTO_INCREMENT PRIMARY KEY,
    bride_name     VARCHAR(100) NOT NULL,
    groom_name     VARCHAR(100) NOT NULL,
    phone          CHAR(10)     NOT NULL UNIQUE,
    email          VARCHAR(100) UNIQUE,
    city           VARCHAR(50),
    registered_on  DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT chk_client_phone CHECK (CHAR_LENGTH(phone) = 10)
);

-- ---------------------------------------------------------------------
-- 3. VENUE : halls / lawns / resorts that can be booked
-- ---------------------------------------------------------------------
CREATE TABLE venue (
    venue_id       INT AUTO_INCREMENT PRIMARY KEY,
    venue_name     VARCHAR(100) NOT NULL,
    venue_type     ENUM('Banquet Hall','Lawn','Resort','Temple','Hotel','Farmhouse') NOT NULL,
    city           VARCHAR(50)  NOT NULL,
    address        VARCHAR(200),
    capacity       INT           NOT NULL,
    price_per_day  DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_venue_capacity CHECK (capacity > 0),
    CONSTRAINT chk_venue_price    CHECK (price_per_day >= 0)
);

-- ---------------------------------------------------------------------
-- 4. WEDDING : one wedding per booking (client 1 : N wedding)
-- ---------------------------------------------------------------------
CREATE TABLE wedding (
    wedding_id     INT AUTO_INCREMENT PRIMARY KEY,
    client_id      INT NOT NULL,
    planner_id     INT,
    wedding_date   DATE NOT NULL,
    theme          VARCHAR(60),
    total_budget   DECIMAL(12,2) NOT NULL,
    status         ENUM('Planning','Confirmed','Completed','Cancelled') NOT NULL DEFAULT 'Planning',
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_wedding_client  FOREIGN KEY (client_id)  REFERENCES client(client_id)   ON DELETE CASCADE,
    CONSTRAINT fk_wedding_planner FOREIGN KEY (planner_id) REFERENCES planner(planner_id) ON DELETE SET NULL,
    CONSTRAINT chk_wedding_budget CHECK (total_budget > 0)
);

-- ---------------------------------------------------------------------
-- 5. EVENT : each function of a wedding (Haldi, Mehendi, Sangeet ...)
--    wedding 1 : N event,  venue 1 : N event
-- ---------------------------------------------------------------------
CREATE TABLE event (
    event_id         INT AUTO_INCREMENT PRIMARY KEY,
    wedding_id       INT NOT NULL,
    venue_id         INT NOT NULL,
    event_type       ENUM('Engagement','Haldi','Mehendi','Sangeet','Wedding Ceremony','Reception') NOT NULL,
    event_date       DATE NOT NULL,
    start_time       TIME NOT NULL,
    end_time         TIME NOT NULL,
    expected_guests  INT  NOT NULL DEFAULT 0,
    CONSTRAINT fk_event_wedding FOREIGN KEY (wedding_id) REFERENCES wedding(wedding_id) ON DELETE CASCADE,
    CONSTRAINT fk_event_venue   FOREIGN KEY (venue_id)   REFERENCES venue(venue_id)     ON DELETE RESTRICT,
    CONSTRAINT uq_venue_per_day   UNIQUE (venue_id, event_date),    -- a venue can host one event a day
    CONSTRAINT uq_event_per_wed   UNIQUE (wedding_id, event_type),  -- one Haldi per wedding, etc.
    CONSTRAINT chk_event_time     CHECK (end_time > start_time),
    CONSTRAINT chk_event_guests   CHECK (expected_guests >= 0)
);

-- ---------------------------------------------------------------------
-- 6. GUEST : guest list of a wedding  (wedding 1 : N guest)
-- ---------------------------------------------------------------------
CREATE TABLE guest (
    guest_id         INT AUTO_INCREMENT PRIMARY KEY,
    wedding_id       INT NOT NULL,
    full_name        VARCHAR(100) NOT NULL,
    phone            CHAR(10),
    email            VARCHAR(100),
    side             ENUM('Bride','Groom') NOT NULL,
    relation         VARCHAR(40),
    meal_preference  ENUM('Veg','Non-Veg','Jain','Vegan') NOT NULL DEFAULT 'Veg',
    plus_ones        TINYINT UNSIGNED NOT NULL DEFAULT 0,
    city             VARCHAR(50),
    CONSTRAINT fk_guest_wedding FOREIGN KEY (wedding_id) REFERENCES wedding(wedding_id) ON DELETE CASCADE,
    CONSTRAINT uq_guest_phone   UNIQUE (wedding_id, phone),
    CONSTRAINT chk_plus_ones    CHECK (plus_ones <= 5)
);

-- ---------------------------------------------------------------------
-- 7. INVITATION : M:N between GUEST and EVENT, with RSVP attributes
-- ---------------------------------------------------------------------
CREATE TABLE invitation (
    guest_id      INT NOT NULL,
    event_id      INT NOT NULL,
    rsvp_status   ENUM('Pending','Accepted','Declined') NOT NULL DEFAULT 'Pending',
    table_no      SMALLINT,
    responded_on  DATETIME,
    PRIMARY KEY (guest_id, event_id),                       -- composite key
    CONSTRAINT fk_inv_guest FOREIGN KEY (guest_id) REFERENCES guest(guest_id) ON DELETE CASCADE,
    CONSTRAINT fk_inv_event FOREIGN KEY (event_id) REFERENCES event(event_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 8. CATERER  &  9. MENU_ITEM  (caterer 1 : N menu_item)
-- ---------------------------------------------------------------------
CREATE TABLE caterer (
    caterer_id    INT AUTO_INCREMENT PRIMARY KEY,
    caterer_name  VARCHAR(100) NOT NULL,
    phone         CHAR(10) NOT NULL UNIQUE,
    city          VARCHAR(50),
    speciality    VARCHAR(60),
    rating        DECIMAL(2,1),
    CONSTRAINT chk_caterer_rating CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE menu_item (
    item_id          INT AUTO_INCREMENT PRIMARY KEY,
    caterer_id       INT NOT NULL,
    item_name        VARCHAR(80) NOT NULL,
    course           ENUM('Welcome Drink','Starter','Main Course','Bread','Rice','Dessert','Beverage') NOT NULL,
    food_type        ENUM('Veg','Non-Veg') NOT NULL,
    price_per_plate  DECIMAL(8,2) NOT NULL,
    CONSTRAINT fk_menu_caterer FOREIGN KEY (caterer_id) REFERENCES caterer(caterer_id) ON DELETE CASCADE,
    CONSTRAINT uq_menu_item    UNIQUE (caterer_id, item_name),
    CONSTRAINT chk_menu_price  CHECK (price_per_plate > 0)
);

-- ---------------------------------------------------------------------
-- 10. CATERING_ORDER : event 1 : 1 catering_order (UNIQUE event_id)
-- 11. ORDER_ITEM     : M:N between CATERING_ORDER and MENU_ITEM
-- ---------------------------------------------------------------------
CREATE TABLE catering_order (
    order_id      INT AUTO_INCREMENT PRIMARY KEY,
    event_id      INT NOT NULL UNIQUE,
    caterer_id    INT NOT NULL,
    no_of_plates  INT NOT NULL,
    order_status  ENUM('Quoted','Confirmed','Served','Cancelled') NOT NULL DEFAULT 'Quoted',
    CONSTRAINT fk_order_event   FOREIGN KEY (event_id)   REFERENCES event(event_id)     ON DELETE CASCADE,
    CONSTRAINT fk_order_caterer FOREIGN KEY (caterer_id) REFERENCES caterer(caterer_id) ON DELETE RESTRICT,
    CONSTRAINT chk_order_plates CHECK (no_of_plates > 0)
);

CREATE TABLE order_item (
    order_id  INT NOT NULL,
    item_id   INT NOT NULL,
    PRIMARY KEY (order_id, item_id),
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES catering_order(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_oi_item  FOREIGN KEY (item_id)  REFERENCES menu_item(item_id)       ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- 12. VENDOR  &  13. VENDOR_BOOKING (M:N between EVENT and VENDOR)
-- ---------------------------------------------------------------------
CREATE TABLE vendor (
    vendor_id     INT AUTO_INCREMENT PRIMARY KEY,
    vendor_name   VARCHAR(100) NOT NULL,
    service_type  ENUM('Photography','Videography','Decoration','Florist','DJ & Music','Band Baaja',
                       'Makeup Artist','Mehendi Artist','Pandit','Lighting','Invitation Cards','Choreographer') NOT NULL,
    phone         CHAR(10) NOT NULL UNIQUE,
    city          VARCHAR(50),
    base_price    DECIMAL(10,2) NOT NULL,
    rating        DECIMAL(2,1),
    CONSTRAINT chk_vendor_price  CHECK (base_price >= 0),
    CONSTRAINT chk_vendor_rating CHECK (rating BETWEEN 0 AND 5)
);

CREATE TABLE vendor_booking (
    booking_id      INT AUTO_INCREMENT PRIMARY KEY,
    event_id        INT NOT NULL,
    vendor_id       INT NOT NULL,
    agreed_price    DECIMAL(10,2),
    booking_status  ENUM('Enquired','Booked','Completed','Cancelled') NOT NULL DEFAULT 'Booked',
    booked_on       DATE NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT fk_vb_event  FOREIGN KEY (event_id)  REFERENCES event(event_id)   ON DELETE CASCADE,
    CONSTRAINT fk_vb_vendor FOREIGN KEY (vendor_id) REFERENCES vendor(vendor_id) ON DELETE RESTRICT,
    CONSTRAINT uq_vb        UNIQUE (event_id, vendor_id),
    CONSTRAINT chk_vb_price CHECK (agreed_price >= 0)
);

-- ---------------------------------------------------------------------
-- 14. HOTEL  &  15. ROOM_BOOKING : accommodation for outstation guests
-- ---------------------------------------------------------------------
CREATE TABLE hotel (
    hotel_id         INT AUTO_INCREMENT PRIMARY KEY,
    hotel_name       VARCHAR(100) NOT NULL,
    city             VARCHAR(50)  NOT NULL,
    star_rating      TINYINT NOT NULL,
    price_per_night  DECIMAL(8,2) NOT NULL,
    phone            CHAR(10),
    CONSTRAINT chk_hotel_star  CHECK (star_rating BETWEEN 1 AND 5),
    CONSTRAINT chk_hotel_price CHECK (price_per_night > 0)
);

CREATE TABLE room_booking (
    room_booking_id  INT AUTO_INCREMENT PRIMARY KEY,
    guest_id         INT NOT NULL,
    hotel_id         INT NOT NULL,
    room_type        ENUM('Single','Double','Suite') NOT NULL DEFAULT 'Double',
    rooms            TINYINT UNSIGNED NOT NULL DEFAULT 1,
    check_in         DATE NOT NULL,
    check_out        DATE NOT NULL,
    CONSTRAINT fk_rb_guest FOREIGN KEY (guest_id) REFERENCES guest(guest_id) ON DELETE CASCADE,
    CONSTRAINT fk_rb_hotel FOREIGN KEY (hotel_id) REFERENCES hotel(hotel_id) ON DELETE RESTRICT,
    CONSTRAINT chk_rb_dates CHECK (check_out > check_in),
    CONSTRAINT chk_rb_rooms CHECK (rooms BETWEEN 1 AND 10)
);

-- ---------------------------------------------------------------------
-- 16. TRANSPORT : cars / buses / ghodi for baraat, guest pickup etc.
-- ---------------------------------------------------------------------
CREATE TABLE transport (
    transport_id      INT AUTO_INCREMENT PRIMARY KEY,
    wedding_id        INT NOT NULL,
    vehicle_type      ENUM('Car','SUV','Tempo Traveller','Bus','Vintage Car','Horse (Ghodi)') NOT NULL,
    vehicle_count     TINYINT UNSIGNED NOT NULL DEFAULT 1,
    cost_per_vehicle  DECIMAL(8,2) NOT NULL,
    pickup_point      VARCHAR(100),
    drop_point        VARCHAR(100),
    trip_date         DATE NOT NULL,
    purpose           VARCHAR(100),
    CONSTRAINT fk_tr_wedding FOREIGN KEY (wedding_id) REFERENCES wedding(wedding_id) ON DELETE CASCADE,
    CONSTRAINT chk_tr_count  CHECK (vehicle_count > 0),
    CONSTRAINT chk_tr_cost   CHECK (cost_per_vehicle >= 0)
);

-- ---------------------------------------------------------------------
-- 17. PAYMENT : money received from the client
-- ---------------------------------------------------------------------
CREATE TABLE payment (
    payment_id    INT AUTO_INCREMENT PRIMARY KEY,
    wedding_id    INT NOT NULL,
    amount        DECIMAL(12,2) NOT NULL,
    payment_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
    mode          ENUM('Cash','UPI','Card','Bank Transfer','Cheque') NOT NULL,
    paid_towards  ENUM('Advance','Venue','Catering','Vendor','Accommodation','Transport','Planner Fee','Other') NOT NULL DEFAULT 'Advance',
    reference_no  VARCHAR(40) UNIQUE,
    CONSTRAINT fk_pay_wedding FOREIGN KEY (wedding_id) REFERENCES wedding(wedding_id) ON DELETE CASCADE,
    CONSTRAINT chk_pay_amount CHECK (amount > 0)
);

-- ---------------------------------------------------------------------
-- 18. TASK : wedding checklist (auto-created by a trigger)
-- ---------------------------------------------------------------------
CREATE TABLE task (
    task_id     INT AUTO_INCREMENT PRIMARY KEY,
    wedding_id  INT NOT NULL,
    title       VARCHAR(150) NOT NULL,
    category    ENUM('Venue','Catering','Guests','Vendors','Shopping','Rituals','Logistics','Other') NOT NULL DEFAULT 'Other',
    due_date    DATE,
    priority    ENUM('Low','Medium','High') NOT NULL DEFAULT 'Medium',
    status      ENUM('To Do','In Progress','Done') NOT NULL DEFAULT 'To Do',
    CONSTRAINT fk_task_wedding FOREIGN KEY (wedding_id) REFERENCES wedding(wedding_id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 19. GIFT : gifts / shagun received from guests
-- ---------------------------------------------------------------------
CREATE TABLE gift (
    gift_id          INT AUTO_INCREMENT PRIMARY KEY,
    guest_id         INT NOT NULL,
    gift_type        ENUM('Cash','Jewellery','Electronics','Home Decor','Clothing','Other') NOT NULL,
    description      VARCHAR(150),
    estimated_value  DECIMAL(10,2) NOT NULL DEFAULT 0,
    received_on      DATE,
    thank_you_sent   BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_gift_guest FOREIGN KEY (guest_id) REFERENCES guest(guest_id) ON DELETE CASCADE,
    CONSTRAINT chk_gift_value CHECK (estimated_value >= 0)
);

-- ---------------------------------------------------------------------
-- 20. AUDIT_LOG : filled automatically by triggers
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    table_name  VARCHAR(40) NOT NULL,
    action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    record_id   INT,
    details     VARCHAR(255),
    done_by     VARCHAR(100),
    logged_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- SECONDARY INDEXES (faster searching / sorting)
-- (Foreign-key columns are indexed automatically by InnoDB)
-- ---------------------------------------------------------------------
CREATE INDEX idx_wedding_date   ON wedding(wedding_date);
CREATE INDEX idx_event_date     ON event(event_date);
CREATE INDEX idx_guest_name     ON guest(full_name);
CREATE INDEX idx_vendor_service ON vendor(service_type, city);
CREATE INDEX idx_venue_city     ON venue(city, capacity);
CREATE INDEX idx_payment_date   ON payment(payment_date);
CREATE INDEX idx_task_status    ON task(status, due_date);
