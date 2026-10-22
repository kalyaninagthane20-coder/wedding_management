-- =====================================================================
--  File 05 : DCL - users, GRANT and REVOKE  (run as an administrator, e.g. root)
--  Not part of 00_run_all.sql because it creates database users.
--  Shows: CREATE USER, GRANT (table / column / view level), SHOW GRANTS, REVOKE, DROP USER
-- =====================================================================
SET NAMES utf8mb4;
USE wedding_db;

-- A read-only user for the client / reception desk
CREATE USER IF NOT EXISTS 'wedding_viewer'@'localhost' IDENTIFIED BY 'Viewer@123';
GRANT SELECT ON wedding_db.vw_wedding_overview TO 'wedding_viewer'@'localhost';
GRANT SELECT ON wedding_db.vw_event_schedule   TO 'wedding_viewer'@'localhost';

-- A planner user: can read everything and manage guests / tasks, but not delete weddings
CREATE USER IF NOT EXISTS 'wedding_planner'@'localhost' IDENTIFIED BY 'Planner@123';
GRANT SELECT ON wedding_db.* TO 'wedding_planner'@'localhost';
GRANT INSERT, UPDATE, DELETE ON wedding_db.guest      TO 'wedding_planner'@'localhost';
GRANT INSERT, UPDATE, DELETE ON wedding_db.invitation TO 'wedding_planner'@'localhost';
GRANT INSERT, UPDATE         ON wedding_db.task       TO 'wedding_planner'@'localhost';
GRANT UPDATE (rsvp_status, table_no) ON wedding_db.invitation TO 'wedding_planner'@'localhost';   -- column-level
GRANT EXECUTE ON PROCEDURE wedding_db.sp_wedding_summary TO 'wedding_planner'@'localhost';

SHOW GRANTS FOR 'wedding_viewer'@'localhost';
SHOW GRANTS FOR 'wedding_planner'@'localhost';

-- Take a privilege away again
REVOKE DELETE ON wedding_db.guest FROM 'wedding_planner'@'localhost';
SHOW GRANTS FOR 'wedding_planner'@'localhost';

-- Clean up (uncomment to remove the demo users)
-- DROP USER 'wedding_viewer'@'localhost';
-- DROP USER 'wedding_planner'@'localhost';
