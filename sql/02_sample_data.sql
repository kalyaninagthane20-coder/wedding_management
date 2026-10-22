-- =====================================================================
--  File 02 : DML - Sample data (INSERT statements)
--  Run AFTER 01_schema.sql.  Parent tables are filled before child
--  tables so that FOREIGN KEY constraints are satisfied.
-- =====================================================================
SET NAMES utf8mb4;
USE wedding_db;

INSERT INTO planner (full_name, phone, email, experience_years, fee) VALUES
('Neha Kulkarni',  '9890011001', 'neha@shaadiplan.in',   8, 120000),
('Rahul Deshmukh', '9890011002', 'rahul@shaadiplan.in',  5,  90000),
('Sanjana Patil',  '9890011003', 'sanjana@shaadiplan.in',12, 150000);

INSERT INTO client (bride_name, groom_name, phone, email, city, registered_on) VALUES
('Priya Sharma',  'Rohan Mehta',   '9811100001', 'priya.rohan@mail.com',  'Pune',       '2026-05-10'),
('Ananya Iyer',   'Karan Malhotra','9811100002', 'ananya.karan@mail.com', 'Mumbai',     '2026-06-02'),
('Sneha Joshi',   'Aditya Rao',    '9811100003', 'sneha.aditya@mail.com', 'Sangli',     '2025-09-15'),
('Meera Kulkarni','Vikram Pawar',  '9811100004', 'meera.vikram@mail.com', 'Kolhapur',   '2026-08-21'),
('Divya Nair',    'Arjun Menon',   '9811100005', 'divya.arjun@mail.com',  'Bengaluru',  '2026-03-30');

INSERT INTO venue (venue_name, venue_type, city, address, capacity, price_per_day) VALUES
('Rajwada Palace',        'Banquet Hall','Pune',    'Koregaon Park, Pune',        800,  80000),
('Shree Siddhi Lawns',    'Lawn',        'Pune',    'Baner Road, Pune',          1500, 120000),
('Rose Garden Resort',    'Resort',      'Mumbai',  'Juhu, Mumbai',               400,  90000),
('The Grand Orchid',      'Hotel',       'Mumbai',  'Andheri East, Mumbai',       700, 150000),
('Seaside Pearl Resort',  'Resort',      'Goa',     'Calangute, Goa',             500, 160000),
('Kolhapur Heritage Hall','Banquet Hall','Kolhapur','Rajarampuri, Kolhapur',      600,  50000),
('Ambabai Temple Mandap', 'Temple',      'Kolhapur','Mahadwar Road, Kolhapur',    300,  15000),
('Lotus Farmhouse',       'Farmhouse',   'Bengaluru','Devanahalli, Bengaluru',    350,  70000),
('Krishna Riverside Lawn','Lawn',        'Sangli',  'Krishna Ghat, Sangli',       900,  40000),
('Hotel Sayaji Ballroom', 'Hotel',       'Pune',    'Wakad, Pune',                450,  75000);

INSERT INTO wedding (client_id, planner_id, wedding_date, theme, total_budget, status) VALUES
(1, 1, '2026-12-05', 'Royal Rajasthani',        2500000, 'Confirmed'),
(2, 2, '2026-11-20', 'Floral Pastel',           1300000, 'Confirmed'),
(3, 1, '2026-02-14', 'Beach Romance',           1200000, 'Completed'),
(4, 3, '2027-01-22', 'Traditional Maharashtrian',700000, 'Planning'),
(5, 2, '2026-10-10', 'Minimalist Garden',        500000, 'Cancelled');

INSERT INTO event (wedding_id, venue_id, event_type, event_date, start_time, end_time, expected_guests) VALUES
(1, 1, 'Mehendi',          '2026-12-03', '16:00', '21:00', 200),  -- 1
(1, 1, 'Sangeet',          '2026-12-04', '19:00', '23:59', 300),  -- 2
(1, 2, 'Wedding Ceremony', '2026-12-05', '10:00', '15:00', 500),  -- 3
(1, 2, 'Reception',        '2026-12-06', '19:00', '23:00', 450),  -- 4
(2, 3, 'Haldi',            '2026-11-18', '10:00', '13:00', 100),  -- 5
(2, 4, 'Wedding Ceremony', '2026-11-20', '11:00', '16:00', 250),  -- 6
(2, 4, 'Reception',        '2026-11-21', '19:00', '23:00', 350),  -- 7
(3, 5, 'Wedding Ceremony', '2026-02-14', '16:00', '20:00', 250),  -- 8
(3, 5, 'Reception',        '2026-02-15', '19:00', '23:00', 300),  -- 9
(4, 6, 'Engagement',       '2026-12-20', '18:00', '22:00', 150),  -- 10
(4, 7, 'Wedding Ceremony', '2027-01-22', '09:00', '14:00', 280),  -- 11
(5, 8, 'Wedding Ceremony', '2026-10-10', '12:00', '17:00', 200);  -- 12

INSERT INTO guest (wedding_id, full_name, phone, email, side, relation, meal_preference, plus_ones, city) VALUES
-- Wedding 1 : Priya & Rohan  (guest_id 1-12)
(1,'Suresh Sharma',   '9700000001','suresh@mail.com',  'Bride','Father',        'Veg',    1,'Pune'),
(1,'Kavita Sharma',   '9700000002','kavita@mail.com',  'Bride','Mother',        'Veg',    0,'Pune'),
(1,'Amit Sharma',     '9700000003',NULL,               'Bride','Brother',       'Non-Veg',1,'Delhi'),
(1,'Pooja Verma',     '9700000004','pooja@mail.com',   'Bride','Best Friend',   'Non-Veg',1,'Nagpur'),
(1,'Ramesh Mehta',    '9700000005',NULL,               'Groom','Father',        'Jain',   1,'Pune'),
(1,'Sunita Mehta',    '9700000006',NULL,               'Groom','Mother',        'Jain',   0,'Pune'),
(1,'Nikhil Mehta',    '9700000007','nikhil@mail.com',  'Groom','Brother',       'Non-Veg',2,'Mumbai'),
(1,'Tanvi Shah',      '9700000008',NULL,               'Groom','Cousin',        'Veg',    1,'Ahmedabad'),
(1,'Harish Kapoor',   '9700000009','harish@mail.com',  'Groom','Uncle',         'Veg',    2,'Jaipur'),
(1,'Isha Gupta',      '9700000010',NULL,               'Bride','College Friend','Vegan',  0,'Hyderabad'),
(1,'Manoj Joshi',     '9700000011',NULL,               'Bride','Uncle',         'Non-Veg',1,'Satara'),
(1,'Rekha Joshi',     '9700000012',NULL,               'Bride','Aunt',          'Veg',    0,'Satara'),
-- Wedding 2 : Ananya & Karan (guest_id 13-20)
(2,'Venkat Iyer',     '9700000013','venkat@mail.com',  'Bride','Father',        'Veg',    1,'Chennai'),
(2,'Lakshmi Iyer',    '9700000014',NULL,               'Bride','Mother',        'Veg',    0,'Chennai'),
(2,'Deepak Malhotra', '9700000015','deepak@mail.com',  'Groom','Father',        'Non-Veg',1,'Mumbai'),
(2,'Simran Malhotra', '9700000016',NULL,               'Groom','Sister',        'Non-Veg',1,'Mumbai'),
(2,'Gaurav Singh',    '9700000017',NULL,               'Groom','Friend',        'Non-Veg',0,'Chandigarh'),
(2,'Divya Rao',       '9700000018',NULL,               'Bride','Friend',        'Veg',    1,'Bengaluru'),
(2,'Prakash Nair',    '9700000019',NULL,               'Bride','Uncle',         'Veg',    2,'Kochi'),
(2,'Meenal Desai',    '9700000020','meenal@mail.com',  'Groom','Colleague',     'Vegan',  0,'Surat'),
-- Wedding 3 : Sneha & Aditya (guest_id 21-26)
(3,'Prasad Joshi',    '9700000021',NULL,               'Bride','Father',        'Veg',    1,'Sangli'),
(3,'Anjali Joshi',    '9700000022',NULL,               'Bride','Mother',        'Veg',    0,'Sangli'),
(3,'Krishna Rao',     '9700000023',NULL,               'Groom','Father',        'Non-Veg',1,'Hyderabad'),
(3,'Lata Rao',        '9700000024',NULL,               'Groom','Mother',        'Non-Veg',0,'Hyderabad'),
(3,'Sameer Kulkarni', '9700000025','sameer@mail.com',  'Bride','Friend',        'Non-Veg',1,'Pune'),
(3,'Rutuja Patil',    '9700000026',NULL,               'Bride','Cousin',        'Veg',    1,'Kolhapur'),
-- Wedding 4 : Meera & Vikram (guest_id 27-30)
(4,'Dilip Kulkarni',  '9700000027',NULL,               'Bride','Father',        'Veg',    1,'Kolhapur'),
(4,'Shobha Kulkarni', '9700000028',NULL,               'Bride','Mother',        'Veg',    0,'Kolhapur'),
(4,'Bhaskar Pawar',   '9700000029',NULL,               'Groom','Father',        'Non-Veg',1,'Satara'),
(4,'Yogesh Pawar',    '9700000030',NULL,               'Groom','Brother',       'Non-Veg',1,'Satara');

INSERT INTO invitation (guest_id, event_id, rsvp_status, table_no, responded_on) VALUES
-- Wedding 1 guests -> events 1..4
(1,2,'Accepted',1,'2026-10-01 10:00:00'),(1,3,'Accepted',1,'2026-10-01 10:00:00'),(1,4,'Accepted',1,'2026-10-01 10:00:00'),
(2,2,'Accepted',1,'2026-10-01 10:05:00'),(2,3,'Accepted',1,'2026-10-01 10:05:00'),(2,4,'Accepted',1,'2026-10-01 10:05:00'),
(3,1,'Accepted',2,'2026-10-02 09:00:00'),(3,2,'Accepted',2,'2026-10-02 09:00:00'),(3,3,'Accepted',2,'2026-10-02 09:00:00'),
(4,1,'Accepted',3,'2026-10-03 18:30:00'),(4,2,'Accepted',3,'2026-10-03 18:30:00'),(4,3,'Declined',NULL,'2026-10-03 18:30:00'),
(5,3,'Accepted',4,'2026-10-04 11:00:00'),(5,4,'Accepted',4,'2026-10-04 11:00:00'),
(6,3,'Accepted',4,'2026-10-04 11:05:00'),(6,4,'Accepted',4,'2026-10-04 11:05:00'),
(7,2,'Accepted',5,'2026-10-05 12:00:00'),(7,3,'Accepted',5,'2026-10-05 12:00:00'),(7,4,'Pending',NULL,NULL),
(8,3,'Pending',NULL,NULL),(8,4,'Pending',NULL,NULL),
(9,3,'Accepted',6,'2026-10-06 15:00:00'),(9,4,'Declined',NULL,'2026-10-06 15:00:00'),
(10,1,'Accepted',2,'2026-10-07 08:00:00'),(10,2,'Accepted',3,'2026-10-07 08:00:00'),
(11,3,'Pending',NULL,NULL),(12,3,'Pending',NULL,NULL),
-- Wedding 2 guests -> events 5..7
(13,5,'Accepted',1,'2026-10-10 10:00:00'),(13,6,'Accepted',1,'2026-10-10 10:00:00'),(13,7,'Accepted',1,'2026-10-10 10:00:00'),
(14,5,'Accepted',1,'2026-10-10 10:00:00'),(14,6,'Accepted',1,'2026-10-10 10:00:00'),
(15,6,'Accepted',2,'2026-10-11 10:00:00'),(15,7,'Accepted',2,'2026-10-11 10:00:00'),
(16,6,'Accepted',2,'2026-10-11 10:00:00'),(16,7,'Pending',NULL,NULL),
(17,6,'Declined',NULL,'2026-10-12 10:00:00'),(17,7,'Accepted',3,'2026-10-12 10:00:00'),
(18,5,'Accepted',4,'2026-10-12 11:00:00'),(18,6,'Accepted',4,'2026-10-12 11:00:00'),
(19,6,'Pending',NULL,NULL),(20,7,'Accepted',5,'2026-10-13 12:00:00'),
-- Wedding 3 guests -> events 8..9
(21,8,'Accepted',1,'2026-01-05 10:00:00'),(21,9,'Accepted',1,'2026-01-05 10:00:00'),
(22,8,'Accepted',1,'2026-01-05 10:00:00'),(22,9,'Accepted',1,'2026-01-05 10:00:00'),
(23,8,'Accepted',2,'2026-01-06 10:00:00'),(23,9,'Accepted',2,'2026-01-06 10:00:00'),
(24,8,'Accepted',2,'2026-01-06 10:00:00'),(24,9,'Accepted',2,'2026-01-06 10:00:00'),
(25,8,'Accepted',3,'2026-01-07 10:00:00'),(25,9,'Declined',NULL,'2026-01-07 10:00:00'),
(26,8,'Accepted',3,'2026-01-07 10:00:00'),(26,9,'Accepted',3,'2026-01-07 10:00:00'),
-- Wedding 4 guests -> events 10..11
(27,10,'Accepted',1,'2026-11-01 10:00:00'),(27,11,'Pending',NULL,NULL),
(28,10,'Accepted',1,'2026-11-01 10:00:00'),(28,11,'Pending',NULL,NULL),
(29,10,'Pending',NULL,NULL),(29,11,'Pending',NULL,NULL),
(30,10,'Pending',NULL,NULL),(30,11,'Pending',NULL,NULL);

INSERT INTO caterer (caterer_name, phone, city, speciality, rating) VALUES
('Annapurna Caterers',  '9822200001','Pune',     'North Indian',        4.5),
('Shahi Rasoi',         '9822200002','Mumbai',   'Mughlai',             4.7),
('Coastal Spice Kitchen','9822200003','Goa',     'Seafood & Konkani',   4.3),
('Green Leaf Caterers', '9822200004','Kolhapur', 'Pure Vegetarian',     4.6);

INSERT INTO menu_item (caterer_id, item_name, course, food_type, price_per_plate) VALUES
(1,'Jaljeera Welcome Drink','Welcome Drink','Veg',     40),   -- 1
(1,'Paneer Tikka',          'Starter',      'Veg',    120),   -- 2
(1,'Dal Makhani',           'Main Course',  'Veg',    150),   -- 3
(1,'Butter Naan',           'Bread',        'Veg',     30),   -- 4
(1,'Gulab Jamun',           'Dessert',      'Veg',     60),   -- 5
(2,'Masala Chaas',          'Beverage',     'Veg',     35),   -- 6
(2,'Chicken Seekh Kebab',   'Starter',      'Non-Veg',180),   -- 7
(2,'Mutton Rogan Josh',     'Main Course',  'Non-Veg',280),   -- 8
(2,'Veg Biryani',           'Rice',         'Veg',    140),   -- 9
(2,'Kulfi Falooda',         'Dessert',      'Veg',     90),   -- 10
(3,'Fish Fry',              'Starter',      'Non-Veg',200),   -- 11
(3,'Prawn Curry',           'Main Course',  'Non-Veg',320),   -- 12
(3,'Steamed Rice',          'Rice',         'Veg',     50),   -- 13
(3,'Sol Kadhi',             'Beverage',     'Veg',     40),   -- 14
(4,'Hara Bhara Kebab',      'Starter',      'Veg',    110),   -- 15
(4,'Paneer Butter Masala',  'Main Course',  'Veg',    160),   -- 16
(4,'Jeera Rice',            'Rice',         'Veg',     70),   -- 17
(4,'Rasmalai',              'Dessert',      'Veg',     80);   -- 18

INSERT INTO catering_order (event_id, caterer_id, no_of_plates, order_status) VALUES
(2, 1, 300,'Confirmed'),(3, 2, 500,'Confirmed'),(4, 2, 450,'Quoted'),
(6, 4, 200,'Confirmed'),(7, 4, 350,'Confirmed'),
(8, 3, 250,'Served'),   (9, 3, 300,'Served'),   (11,1, 280,'Quoted');

INSERT INTO order_item (order_id, item_id) VALUES
(1,1),(1,2),(1,3),(1,4),(1,5),
(2,6),(2,7),(2,8),(2,9),(2,10),
(3,6),(3,8),(3,9),(3,10),
(4,15),(4,16),(4,17),(4,18),
(5,15),(5,16),(5,17),(5,18),
(6,11),(6,12),(6,13),(6,14),
(7,11),(7,12),(7,13),(7,14),
(8,1),(8,3),(8,4),(8,5);

INSERT INTO vendor (vendor_name, service_type, phone, city, base_price, rating) VALUES
('Candid Clicks Studio',  'Photography',   '9833300001','Pune',    45000,4.8),  -- 1
('Reel Weddings',         'Videography',   '9833300002','Mumbai',  40000,4.6),  -- 2
('Royal Mandap Decor',    'Decoration',    '9833300003','Pune',   150000,4.7),  -- 3
('Phool Bagh Florists',   'Florist',       '9833300004','Mumbai',  60000,4.4),  -- 4
('DJ Beat Boxx',          'DJ & Music',    '9833300005','Pune',    35000,4.5),  -- 5
('Shehnai Brass Band',    'Band Baaja',    '9833300006','Kolhapur',25000,4.2),  -- 6
('Glam by Riya',          'Makeup Artist', '9833300007','Mumbai',  30000,4.9),  -- 7
('Henna Art by Salma',    'Mehendi Artist','9833300008','Pune',    15000,4.7),  -- 8
('Pt. Shrikant Joshi',    'Pandit',        '9833300009','Pune',    11000,4.9),  -- 9
('Lumina Lighting',       'Lighting',      '9833300010','Goa',     40000,4.3),  -- 10
('Dance Dhamaka',         'Choreographer', '9833300011','Mumbai',  20000,4.5),  -- 11
('Card Kraft Invites',    'Invitation Cards','9833300012','Pune',  18000,4.1);  -- 12

INSERT INTO vendor_booking (event_id, vendor_id, agreed_price, booking_status, booked_on) VALUES
(1, 8, 16000,'Booked',    '2026-09-01'),
(2, 5, 38000,'Booked',    '2026-09-01'),(2,11,22000,'Booked','2026-09-02'),(2,10,42000,'Booked','2026-09-02'),
(3, 1, 50000,'Booked',    '2026-09-03'),(3, 3,160000,'Booked','2026-09-03'),(3, 9,11000,'Booked','2026-09-03'),(3,6,25000,'Booked','2026-09-04'),
(4, 2, 42000,'Booked',    '2026-09-05'),(4, 4, 65000,'Enquired','2026-09-05'),
(6, 1, 45000,'Booked',    '2026-09-10'),(6, 7, 32000,'Booked',  '2026-09-10'),(6, 9,11000,'Booked','2026-09-10'),
(7, 5, 35000,'Booked',    '2026-09-11'),(7, 4, 60000,'Booked',  '2026-09-11'),
(8, 1, 48000,'Completed', '2025-12-01'),(8, 3,140000,'Completed','2025-12-01'),(8,10,40000,'Completed','2025-12-02'),(8,9,11000,'Completed','2025-12-02'),
(9, 5, 35000,'Completed', '2025-12-03'),(9, 2, 40000,'Completed','2025-12-03'),
(11,9, 11000,'Booked',    '2026-10-01'),(11,6, 25000,'Enquired','2026-10-02'),
(12,3, 90000,'Cancelled', '2026-04-01');

INSERT INTO hotel (hotel_name, city, star_rating, price_per_night, phone) VALUES
('Hotel Sayaji',       'Pune',    5, 7500,'9844400001'),
('Taj Lands Edge',     'Mumbai',  5,12000,'9844400002'),
('Comfort Inn',        'Pune',    3, 3000,'9844400003'),
('Goa Sunrise Resort', 'Goa',     4, 6500,'9844400004'),
('Heritage Residency', 'Kolhapur',3, 2800,'9844400005');

INSERT INTO room_booking (guest_id, hotel_id, room_type, rooms, check_in, check_out) VALUES
(3, 1,'Double',1,'2026-12-02','2026-12-07'),
(4, 3,'Single',1,'2026-12-03','2026-12-06'),
(7, 1,'Suite', 1,'2026-12-03','2026-12-06'),
(8, 3,'Double',1,'2026-12-04','2026-12-06'),
(9, 1,'Double',2,'2026-12-03','2026-12-07'),
(10,3,'Single',1,'2026-12-03','2026-12-06'),
(13,2,'Suite', 1,'2026-11-18','2026-11-22'),
(15,2,'Double',1,'2026-11-19','2026-11-22'),
(17,2,'Single',1,'2026-11-19','2026-11-22'),
(23,4,'Double',1,'2026-02-13','2026-02-16'),
(24,4,'Double',1,'2026-02-13','2026-02-16'),
(25,4,'Single',1,'2026-02-13','2026-02-15');

INSERT INTO transport (wedding_id, vehicle_type, vehicle_count, cost_per_vehicle, pickup_point, drop_point, trip_date, purpose) VALUES
(1,'Vintage Car',     1, 25000,'Groom Home, Pune','Shree Siddhi Lawns','2026-12-05','Groom Baraat Entry'),
(1,'Horse (Ghodi)',   1, 12000,'Groom Home, Pune','Shree Siddhi Lawns','2026-12-05','Baraat'),
(1,'Tempo Traveller', 4,  9000,'Pune Airport',    'Hotel Sayaji',      '2026-12-02','Guest Pickup'),
(1,'Bus',             2, 15000,'Hotel Sayaji',    'Shree Siddhi Lawns','2026-12-05','Guest Shuttle'),
(2,'SUV',             3,  6000,'Mumbai Airport',  'The Grand Orchid',  '2026-11-19','Family Pickup'),
(2,'Vintage Car',     1, 20000,'Bride Home',      'The Grand Orchid',  '2026-11-20','Bridal Entry'),
(3,'Car',             6,  4500,'Goa Airport',     'Seaside Pearl Resort','2026-02-13','Guest Pickup'),
(4,'Bus',             2, 14000,'Satara',          'Ambabai Temple Mandap','2027-01-22','Varat Travel');

INSERT INTO payment (wedding_id, amount, payment_date, mode, paid_towards, reference_no) VALUES
(1, 300000,'2026-05-15','Bank Transfer','Advance',     'TXN-1001'),
(1, 400000,'2026-08-20','UPI',          'Venue',       'TXN-1002'),
(1, 250000,'2026-10-05','Cheque',       'Catering',    'CHQ-5531'),
(2, 200000,'2026-06-10','UPI',          'Advance',     'TXN-2001'),
(2, 250000,'2026-09-12','Card',         'Vendor',      'TXN-2002'),
(3, 400000,'2025-10-01','Bank Transfer','Advance',     'TXN-3001'),
(3, 500000,'2025-12-10','Bank Transfer','Venue',       'TXN-3002'),
(3, 250000,'2026-02-10','UPI',          'Catering',    'TXN-3003'),
(4, 100000,'2026-09-01','UPI',          'Advance',     'TXN-4001'),
(5,  50000,'2026-04-02','Cash',         'Advance',     'TXN-5001');

INSERT INTO task (wedding_id, title, category, due_date, priority, status) VALUES
(1,'Finalise Sangeet playlist',        'Vendors',  '2026-11-15','Medium','In Progress'),
(1,'Confirm final guest count',        'Guests',   '2026-11-20','High',  'To Do'),
(1,'Book bridal lehenga fitting',      'Shopping', '2026-10-30','High',  'Done'),
(1,'Arrange shuttle for outstation guests','Logistics','2026-11-25','Medium','To Do'),
(2,'Decide Reception menu tasting',    'Catering', '2026-10-28','High',  'In Progress'),
(2,'Send RSVP reminders',              'Guests',   '2026-10-25','High',  'To Do'),
(2,'Pandit muhurat confirmation',      'Rituals',  '2026-11-01','High',  'Done'),
(3,'Send thank-you cards',             'Guests',   '2026-03-01','Low',   'Done'),
(4,'Shortlist photographers',          'Vendors',  '2026-11-30','Medium','To Do'),
(4,'Book Engagement hall decor',       'Venue',    '2026-12-01','High',  'To Do');

INSERT INTO gift (guest_id, gift_type, description, estimated_value, received_on, thank_you_sent) VALUES
(21,'Cash',       'Shagun envelope',          11000,'2026-02-14',TRUE),
(22,'Jewellery',  'Gold necklace set',        85000,'2026-02-14',TRUE),
(23,'Electronics','Smart TV 55 inch',         52000,'2026-02-14',TRUE),
(24,'Home Decor', 'Silver Lakshmi idol',      18000,'2026-02-14',TRUE),
(25,'Clothing',   'Designer sherwani',        14000,'2026-02-14',FALSE),
(26,'Cash',       'Shagun envelope',           5100,'2026-02-15',FALSE),
(1, 'Jewellery',  'Diamond earrings (pre-wedding gift)', 60000,'2026-10-15',FALSE);
