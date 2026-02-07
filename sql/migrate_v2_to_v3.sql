-- DPS Airlines v2 to v3 Migration Script
-- IMPORTANT: Back up your database before running this migration!
-- This script assumes the v2 tables exist (airline_pilot_stats, airline_flights, etc.)

-- Step 1: Add new columns to airline_pilot_stats
ALTER TABLE `airline_pilot_stats`
    ADD COLUMN IF NOT EXISTS `role` VARCHAR(30) NOT NULL DEFAULT 'captain' AFTER `citizenid`,
    ADD COLUMN IF NOT EXISTS `copilot_hours` FLOAT NOT NULL DEFAULT 0 AFTER `flight_hours`,
    ADD COLUMN IF NOT EXISTS `attendant_flights` INT NOT NULL DEFAULT 0 AFTER `copilot_hours`,
    ADD COLUMN IF NOT EXISTS `ground_tasks_completed` INT NOT NULL DEFAULT 0 AFTER `attendant_flights`,
    ADD COLUMN IF NOT EXISTS `dispatches_created` INT NOT NULL DEFAULT 0 AFTER `ground_tasks_completed`,
    ADD COLUMN IF NOT EXISTS `service_rating` FLOAT NOT NULL DEFAULT 5.0 AFTER `dispatches_created`,
    ADD COLUMN IF NOT EXISTS `landing_rating` FLOAT NOT NULL DEFAULT 5.0 AFTER `service_rating`,
    ADD COLUMN IF NOT EXISTS `reputation` INT NOT NULL DEFAULT 100 AFTER `incidents`,
    ADD COLUMN IF NOT EXISTS `type_ratings` TEXT DEFAULT NULL AFTER `licenses`;

-- Step 2: Create new tables (safe with IF NOT EXISTS)
CREATE TABLE IF NOT EXISTS `airline_role_assignments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` VARCHAR(30) NOT NULL,
    `assigned_by` VARCHAR(50) DEFAULT NULL,
    `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_citizen_role` (`citizenid`),
    KEY `idx_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_crew_assignments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `flight_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` VARCHAR(30) NOT NULL,
    `pay_amount` INT NOT NULL DEFAULT 0,
    `boarded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_flight` (`flight_id`),
    KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_ground_tasks` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `task_type` VARCHAR(30) NOT NULL,
    `airport_code` VARCHAR(10) NOT NULL,
    `assigned_to` VARCHAR(50) DEFAULT NULL,
    `flight_id` INT DEFAULT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
    `pay_amount` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_assigned` (`assigned_to`),
    KEY `idx_status` (`status`),
    KEY `idx_airport` (`airport_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_passenger_reviews` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `flight_id` INT NOT NULL,
    `landing_quality` FLOAT NOT NULL DEFAULT 3.0,
    `service_quality` FLOAT NOT NULL DEFAULT 3.0,
    `time_quality` FLOAT NOT NULL DEFAULT 3.0,
    `overall_rating` FLOAT NOT NULL DEFAULT 3.0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_flight` (`flight_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_cargo_contracts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `contract_name` VARCHAR(100) NOT NULL,
    `client_name` VARCHAR(100) NOT NULL,
    `total_deliveries` INT NOT NULL DEFAULT 3,
    `completed_deliveries` INT NOT NULL DEFAULT 0,
    `cargo_type` VARCHAR(50) NOT NULL DEFAULT 'general',
    `weight_per_delivery` INT NOT NULL DEFAULT 500,
    `pay_per_delivery` INT NOT NULL DEFAULT 500,
    `completion_bonus` INT NOT NULL DEFAULT 0,
    `deadline` TIMESTAMP NULL DEFAULT NULL,
    `assigned_to` VARCHAR(50) DEFAULT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'available',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_assigned` (`assigned_to`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_heli_ops` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `operation_type` VARCHAR(30) NOT NULL,
    `pilot_citizenid` VARCHAR(50) NOT NULL,
    `helicopter_model` VARCHAR(50) NOT NULL,
    `origin_code` VARCHAR(10) NOT NULL,
    `destination_code` VARCHAR(10) DEFAULT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'active',
    `duration` INT NOT NULL DEFAULT 0,
    `pay_amount` INT NOT NULL DEFAULT 0,
    `details` TEXT DEFAULT NULL,
    `started_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_pilot` (`pilot_citizenid`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_flight_tracker` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `flight_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `pos_x` FLOAT NOT NULL DEFAULT 0,
    `pos_y` FLOAT NOT NULL DEFAULT 0,
    `pos_z` FLOAT NOT NULL DEFAULT 0,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `speed` FLOAT NOT NULL DEFAULT 0,
    `altitude` FLOAT NOT NULL DEFAULT 0,
    `fuel_level` FLOAT NOT NULL DEFAULT 100,
    `phase` INT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_flight_tracker` (`flight_id`),
    KEY `idx_citizen` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_dispatch_schedules` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `dispatcher_citizenid` VARCHAR(50) NOT NULL,
    `flight_number` VARCHAR(20) NOT NULL,
    `departure_airport` VARCHAR(10) NOT NULL,
    `arrival_airport` VARCHAR(10) NOT NULL,
    `aircraft_model` VARCHAR(50) NOT NULL,
    `assigned_pilot` VARCHAR(50) DEFAULT NULL,
    `assigned_copilot` VARCHAR(50) DEFAULT NULL,
    `scheduled_time` TIMESTAMP NULL DEFAULT NULL,
    `passengers` INT NOT NULL DEFAULT 0,
    `cargo_weight` INT NOT NULL DEFAULT 0,
    `priority` VARCHAR(20) NOT NULL DEFAULT 'normal',
    `status` VARCHAR(20) NOT NULL DEFAULT 'pending',
    `notes` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_dispatcher` (`dispatcher_citizenid`),
    KEY `idx_pilot` (`assigned_pilot`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_maintenance` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `aircraft_model` VARCHAR(50) NOT NULL,
    `airport_code` VARCHAR(10) NOT NULL,
    `condition_pct` INT NOT NULL DEFAULT 100,
    `flights_since_inspection` INT NOT NULL DEFAULT 0,
    `last_inspection` TIMESTAMP NULL DEFAULT NULL,
    `status` VARCHAR(20) NOT NULL DEFAULT 'good',
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_aircraft_airport` (`aircraft_model`, `airport_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_incidents` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `flight_id` INT DEFAULT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `incident_type` VARCHAR(50) NOT NULL,
    `severity` VARCHAR(20) NOT NULL DEFAULT 'minor',
    `description` TEXT DEFAULT NULL,
    `resolved` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_citizen` (`citizenid`),
    KEY `idx_type` (`incident_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_flight_school` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `lessons_completed` INT NOT NULL DEFAULT 0,
    `flight_hours_logged` FLOAT NOT NULL DEFAULT 0,
    `checkride_passed` TINYINT(1) NOT NULL DEFAULT 0,
    `checkride_attempts` INT NOT NULL DEFAULT 0,
    `enrolled_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `graduated_at` TIMESTAMP NULL DEFAULT NULL,
    UNIQUE KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_company_ledger` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `transaction_type` VARCHAR(30) NOT NULL,
    `amount` INT NOT NULL,
    `description` VARCHAR(255) DEFAULT NULL,
    `initiated_by` VARCHAR(50) DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_type` (`transaction_type`),
    KEY `idx_date` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Step 3: Migrate grade mappings
-- Old: trainee(0) -> ground_crew(1), pilot(1) -> captain(4), boss(2) -> chief_pilot(5)
-- Insert role assignments based on old job grades

-- Map existing pilots (grade 1 in old system) to captain role
INSERT IGNORE INTO `airline_role_assignments` (`citizenid`, `role`, `assigned_by`)
SELECT `citizenid`, 'captain', 'system_migration'
FROM `airline_pilot_stats`
WHERE `role` = 'captain' OR `role` = 'ground_crew';

-- Update pilot_stats role field based on old data
UPDATE `airline_pilot_stats`
SET `role` = CASE
    WHEN `flight_hours` >= 50 THEN 'captain'
    WHEN `flight_hours` >= 20 THEN 'first_officer'
    ELSE 'ground_crew'
END
WHERE `role` = 'captain' OR `role` = 'ground_crew';

-- Step 4: Add copilot column to airline_flights if missing
ALTER TABLE `airline_flights`
    ADD COLUMN IF NOT EXISTS `copilot_citizenid` VARCHAR(50) DEFAULT NULL AFTER `pilot_citizenid`,
    ADD COLUMN IF NOT EXISTS `fuel_used` FLOAT NOT NULL DEFAULT 0 AFTER `duration`,
    ADD COLUMN IF NOT EXISTS `landing_speed` FLOAT DEFAULT NULL AFTER `fuel_used`,
    ADD COLUMN IF NOT EXISTS `landing_quality` VARCHAR(20) DEFAULT NULL AFTER `landing_speed`,
    ADD COLUMN IF NOT EXISTS `weather_conditions` VARCHAR(20) DEFAULT NULL AFTER `landing_quality`;

-- Step 5: Verify migration
SELECT 'Migration complete. Summary:' AS status;
SELECT COUNT(*) AS total_pilots FROM `airline_pilot_stats`;
SELECT COUNT(*) AS role_assignments FROM `airline_role_assignments`;
SELECT COUNT(*) AS existing_flights FROM `airline_flights`;
