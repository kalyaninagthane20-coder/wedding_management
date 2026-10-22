-- Runs the whole database set-up in one go.
-- From the project folder:   mysql -u root -p < sql/00_run_all.sql
-- (or inside the mysql client / MySQL Workbench shell:   source sql/00_run_all.sql)
SET NAMES utf8mb4;
source sql/01_schema.sql
source sql/02_sample_data.sql
source sql/03_views_functions_procedures_triggers.sql
SELECT 'wedding_db created: tables, data, views, functions, procedures and triggers loaded.' AS status;
