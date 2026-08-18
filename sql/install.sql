-- DPS Airlines v3.0 - Full Database Schema
-- Run this on a fresh install (no existing dps-airlines tables)

CREATE TABLE IF NOT EXISTS `airline_pilot_stats` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` VARCHAR(30) NOT NULL DEFAULT 'ground_crew',
    `total_flights` INT NOT NULL DEFAULT 0,
    `successful_flights` INT NOT NULL DEFAULT 0,
    `failed_flights` INT NOT NULL DEFAULT 0,
    `total_passengers` INT NOT NULL DEFAULT 0,
    `total_cargo` INT NOT NULL DEFAULT 0,
    `total_distance` FLOAT NOT NULL DEFAULT 0,
    `total_earnings` INT NOT NULL DEFAULT 0,
    `flight_hours` FLOAT NOT NULL DEFAULT 0,
    `copilot_hours` FLOAT NOT NULL DEFAULT 0,
    `attendant_flights` INT NOT NULL DEFAULT 0,
    `ground_tasks_completed` INT NOT NULL DEFAULT 0,
    `dispatches_created` INT NOT NULL DEFAULT 0,
    `service_rating` FLOAT NOT NULL DEFAULT 5.0,
    `landing_rating` FLOAT NOT NULL DEFAULT 5.0,
    `incidents` INT NOT NULL DEFAULT 0,
    `reputation` INT NOT NULL DEFAULT 100,
    `licenses` TEXT DEFAULT NULL,
    `type_ratings` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_role_assignments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` VARCHAR(30) NOT NULL,
    `assigned_by` VARCHAR(50) DEFAULT NULL,
    `assigned_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `idx_citizen_role` (`citizenid`),
    KEY `idx_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_flights` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `flight_number` VARCHAR(20) NOT NULL,
    `pilot_citizenid` VARCHAR(50) NOT NULL,
    `copilot_citizenid` VARCHAR(50) DEFAULT NULL,
    `aircraft_model` VARCHAR(50) NOT NULL,
    `departure_airport` VARCHAR(10) NOT NULL,
    `arrival_airport` VARCHAR(10) NOT NULL,
    `passengers` INT NOT NULL DEFAULT 0,
    `cargo_weight` INT NOT NULL DEFAULT 0,
    `flight_type` VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    `status` VARCHAR(20) NOT NULL DEFAULT 'active',
    `distance` FLOAT NOT NULL DEFAULT 0,
    `duration` INT NOT NULL DEFAULT 0,
    `fuel_used` FLOAT NOT NULL DEFAULT 0,
    `landing_speed` FLOAT DEFAULT NULL,
    `landing_quality` VARCHAR(20) DEFAULT NULL,
    `weather_conditions` VARCHAR(20) DEFAULT NULL,
    `total_pay` INT NOT NULL DEFAULT 0,
    `departure_time` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `arrival_time` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_pilot` (`pilot_citizenid`),
    KEY `idx_status` (`status`),
    KEY `idx_departure` (`departure_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `airline_crew_assignments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `flight_id` INT NOT NULL,
    `citizenid` VARCHAR(50) NOT NULL,
    `role` VARCHAR(30) NOT NULL,
    `pay_amount` INT NOT NULL DEFAULT 0,
    `boarded_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_flight` (`flight_id`),
    KEY `idx_citizen` (`citizenid`),
    CONSTRAINT `fk_crew_flight` FOREIGN KEY (`flight_id`) REFERENCES `airline_flights` (`id`) ON DELETE CASCADE
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
    KEY `idx_flight` (`flight_id`),
    CONSTRAINT `fk_review_flight` FOREIGN KEY (`flight_id`) REFERENCES `airline_flights` (`id`) ON DELETE CASCADE
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
