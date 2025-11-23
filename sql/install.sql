-- QBX Taxi Job Database Tables
-- Run this SQL file to set up the database

-- Users table (extends player data)
CREATE TABLE IF NOT EXISTS `taxi_users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `name` VARCHAR(100) NOT NULL,
    `phone` VARCHAR(20),
    `autopay_enabled` TINYINT(1) DEFAULT NULL COMMENT 'NULL=not set (defaults to true), 0=disabled, 1=enabled',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Drivers table (taxi drivers)
CREATE TABLE IF NOT EXISTS `taxi_drivers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `name` VARCHAR(100) NOT NULL,
    `license` VARCHAR(50),
    `vehicle_model` VARCHAR(50),
    `vehicle_plate` VARCHAR(20),
    `rating` DECIMAL(3, 2) DEFAULT 5.00,
    `total_rides` INT DEFAULT 0,
    `total_earnings` DECIMAL(10, 2) DEFAULT 0.00,
    `is_active` TINYINT(1) DEFAULT 1,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_active` (`is_active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vehicles table (taxi vehicles)
CREATE TABLE IF NOT EXISTS `taxi_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(20) NOT NULL UNIQUE,
    `model` VARCHAR(50) NOT NULL,
    `vehicle_type` ENUM('rented','own') NOT NULL DEFAULT 'own',
    `driver_cid` VARCHAR(50),
    `location` VARCHAR(100),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_plate` (`plate`),
    INDEX `idx_driver` (`driver_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rides table (ride records)
CREATE TABLE IF NOT EXISTS `taxi_rides` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `ride_id` VARCHAR(50) NOT NULL UNIQUE,
    `passenger_cid` VARCHAR(50) NOT NULL,
    `passenger_name` VARCHAR(100),
    `driver_cid` VARCHAR(50) NOT NULL,
    `driver_name` VARCHAR(100),
    `pickup_location` VARCHAR(200),
    `dropoff_location` VARCHAR(200),
    `pickup_message` TEXT,
    `fare` DECIMAL(10, 2) DEFAULT 0.00,
    `distance` DECIMAL(10, 2) DEFAULT 0.00,
    `status` ENUM('pending', 'accepted', 'in_progress', 'completed', 'cancelled') DEFAULT 'pending',
    `payment_method` ENUM('cash', 'debit') DEFAULT 'cash',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL,
    INDEX `idx_ride_id` (`ride_id`),
    INDEX `idx_passenger` (`passenger_cid`),
    INDEX `idx_driver` (`driver_cid`),
    INDEX `idx_status` (`status`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Transactions table (payment records)
CREATE TABLE IF NOT EXISTS `taxi_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `transaction_id` VARCHAR(50) NOT NULL UNIQUE,
    `ride_id` VARCHAR(50) NOT NULL,
    `passenger_cid` VARCHAR(50) NOT NULL,
    `driver_cid` VARCHAR(50) NOT NULL,
    `amount` DECIMAL(10, 2) NOT NULL,
    `payment_method` ENUM('cash', 'debit') NOT NULL,
    `status` ENUM('pending', 'completed', 'failed') DEFAULT 'pending',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_transaction_id` (`transaction_id`),
    INDEX `idx_ride_id` (`ride_id`),
    INDEX `idx_passenger` (`passenger_cid`),
    INDEX `idx_driver` (`driver_cid`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reviews table (driver reviews)
CREATE TABLE IF NOT EXISTS `taxi_reviews` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `review_id` VARCHAR(50) NOT NULL UNIQUE,
    `ride_id` VARCHAR(50) NOT NULL,
    `passenger_cid` VARCHAR(50) NOT NULL,
    `driver_cid` VARCHAR(50) NOT NULL,
    `rating` TINYINT NOT NULL CHECK (`rating` >= 1 AND `rating` <= 5),
    `comment` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_review_id` (`review_id`),
    INDEX `idx_ride_id` (`ride_id`),
    INDEX `idx_driver` (`driver_cid`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Driver stats table (aggregated statistics)
CREATE TABLE IF NOT EXISTS `taxi_driver_stats` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `driver_cid` VARCHAR(50) NOT NULL UNIQUE,
    `total_reviews` INT DEFAULT 0,
    `average_rating` DECIMAL(3, 2) DEFAULT 0.00,
    `total_rating_sum` INT DEFAULT 0,
    `rating_1_count` INT DEFAULT 0,
    `rating_2_count` INT DEFAULT 0,
    `rating_3_count` INT DEFAULT 0,
    `rating_4_count` INT DEFAULT 0,
    `rating_5_count` INT DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_driver_cid` (`driver_cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
