-- Database abstraction layer for qbx_taxijob using MySQL via oxmysql
-- Migrated from JSON to MySQL database
-- File: server/db.lua

---@class TaxiMySQLDB
local DB = {
    driverActiveRide = {}, -- [driver_id=citizenid] = ride_id (in-memory cache)
}

-- Utilities to extract IDs and names from qbx_core player
local function getCitizenId(player)
    return player and player.PlayerData and player.PlayerData.citizenid or nil
end

local function getPlayerName(player)
    if not player or not player.PlayerData then return 'unknown' end
    local ci = player.PlayerData.charinfo
    if ci and ci.firstname and ci.lastname then
        return ci.firstname .. ' ' .. ci.lastname
    end
    return player.PlayerData.name or 'unknown'
end

-- ============================================================================
-- INITIALIZATION & UTILITIES
-- ============================================================================

function DB.init()
    CreateThread(function()
        Wait(1000) -- Wait for oxmysql to be ready
        DB.checkTables()
    end)
end

function DB.checkTables()
    local tables = {
        'taxi_users', 'taxi_drivers', 'taxi_vehicles', 'taxi_rides',
        'taxi_transactions', 'taxi_reviews', 'taxi_driver_stats'
    }
    
    print('[qbx_taxijob] [DB] Checking MySQL database tables...')
    
    for _, table_name in ipairs(tables) do
        local exists = MySQL.scalar.await(
            'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
            { table_name }
        )
        
        if exists > 0 then
            print(('[qbx_taxijob] [DB] ✓ Table exists: %s'):format(table_name))
        else
            print(('[qbx_taxijob] [DB] ✗ Table missing: %s - Please run sql/install.sql'):format(table_name))
        end
    end
    
    print('[qbx_taxijob] [DB] Database check complete')
end

-- ============================================================================
-- USER FUNCTIONS
-- ============================================================================

function DB.upsertUserFromPlayer(player)
    local uid = getCitizenId(player)
    if not uid then return end
    
    local name = getPlayerName(player)
    local phone = player.PlayerData and player.PlayerData.charinfo and player.PlayerData.charinfo.phone or ''
    
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM taxi_users WHERE citizenid = ?', { uid })
    
    if existing > 0 then
        MySQL.update.await('UPDATE taxi_users SET name = ?, phone = ? WHERE citizenid = ?', { name, phone, uid })
    else
        MySQL.insert.await('INSERT INTO taxi_users (citizenid, name, phone) VALUES (?, ?, ?)', { uid, name, phone })
    end
end

-- ============================================================================
-- DRIVER FUNCTIONS
-- ============================================================================

-- availability_status: 'off' | 'available' | 'busy'
function DB.updateDriverStatusFromPlayer(player, onDuty)
    local did = getCitizenId(player)
    if not did then return end
    
    local name = getPlayerName(player)
    local job = player.PlayerData and player.PlayerData.job and player.PlayerData.job.name or 'unknown'
    
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM taxi_drivers WHERE citizenid = ?', { did })
    
    if existing > 0 then
        MySQL.update.await('UPDATE taxi_drivers SET name = ?, is_active = ? WHERE citizenid = ?', {
            name, onDuty and 1 or 0, did
        })
    else
        MySQL.insert.await('INSERT INTO taxi_drivers (citizenid, name, is_active) VALUES (?, ?, ?)', {
            did, name, onDuty and 1 or 0
        })
    end
end

function DB.assignVehicleToDriver(player, plate, model)
    local did = getCitizenId(player)
    if not did or not plate then return end
    
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM taxi_vehicles WHERE plate = ?', { plate })
    
    if existing > 0 then
        MySQL.update.await('UPDATE taxi_vehicles SET driver_cid = ?, model = ? WHERE plate = ?', {
            did, model, plate
        })
    else
        MySQL.insert.await('INSERT INTO taxi_vehicles (plate, model, driver_cid) VALUES (?, ?, ?)', {
            plate, model, did
        })
    end
    
    -- Update driver's vehicle info
    MySQL.update.await('UPDATE taxi_drivers SET vehicle_model = ?, vehicle_plate = ? WHERE citizenid = ?', {
        model, plate, did
    })
end

-- ============================================================================
-- RIDE FUNCTIONS
-- ============================================================================

function DB.createRide(ride_id, requesterPlayer, pickup, message)
    if not ride_id then return end
    local uid = getCitizenId(requesterPlayer)
    if not uid then return end
    
    DB.upsertUserFromPlayer(requesterPlayer)
    
    local passenger_name = getPlayerName(requesterPlayer)
    local pickup_loc = pickup and json.encode({ x = pickup.x, y = pickup.y, z = pickup.z }) or nil
    
    MySQL.insert.await(
        'INSERT INTO taxi_rides (ride_id, passenger_cid, passenger_name, driver_cid, driver_name, pickup_location, pickup_message, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { ride_id, uid, passenger_name, '', '', pickup_loc, message or '', 'pending' }
    )
    
    print(('[qbx_taxijob] [DB] Created ride: %s'):format(ride_id))
end

function DB.acceptRide(ride_id, driverPlayer)
    if not ride_id then return end
    local did = getCitizenId(driverPlayer)
    if not did then return end
    
    DB.updateDriverStatusFromPlayer(driverPlayer, true)
    
    local driver_name = getPlayerName(driverPlayer)
    
    MySQL.update.await('UPDATE taxi_rides SET driver_cid = ?, driver_name = ?, status = ? WHERE ride_id = ?', {
        did, driver_name, 'accepted', ride_id
    })
    
    DB.driverActiveRide[did] = ride_id
    print(('[qbx_taxijob] [DB] Driver %s accepted ride: %s'):format(did, ride_id))
end

function DB.markInProgressByDriver(driverPlayer)
    local did = getCitizenId(driverPlayer)
    if not did then return end
    local ride_id = DB.driverActiveRide[did]
    if not ride_id then return end
    
    MySQL.update.await('UPDATE taxi_rides SET status = ? WHERE ride_id = ? AND status != ?', {
        'in_progress', ride_id, 'in_progress'
    })
end

function DB.completeRideByDriver(driverPlayer)
    local did = getCitizenId(driverPlayer)
    if not did then return end
    local ride_id = DB.driverActiveRide[did]
    
    if ride_id then
        MySQL.update.await('UPDATE taxi_rides SET status = ?, completed_at = NOW() WHERE ride_id = ?', {
            'completed', ride_id
        })
    end
    
    DB.driverActiveRide[did] = nil
    print(('[qbx_taxijob] [DB] Driver %s completed ride: %s'):format(did, ride_id))
end

-- ============================================================================
-- TRANSACTION FUNCTIONS
-- ============================================================================

function DB.addTransaction(user_id, driver_id, ride_id, amount, payment_status)
    local transaction_id = ('tx_%s_%s'):format(os.time(), math.random(1000, 9999))
    
    MySQL.insert.await(
        'INSERT INTO taxi_transactions (transaction_id, ride_id, passenger_cid, driver_cid, amount, payment_method, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { transaction_id, ride_id, user_id, driver_id, tonumber(amount) or 0, 'cash', payment_status or 'pending' }
    )
    
    print(('[qbx_taxijob] [DB] Created transaction: %s'):format(transaction_id))
    return transaction_id
end

-- ============================================================================
-- REVIEW AND RATING FUNCTIONS
-- ============================================================================

function DB.addReview(user_id, driver_id, ride_id, rating, comment)
    -- Validate rating
    if rating < 1 or rating > 5 then
        print(('[qbx_taxijob] [DB] [ERROR] Invalid rating: %s (must be 1-5)'):format(rating))
        return nil
    end
    
    local review_id = ('review_%s_%s'):format(driver_id, os.time())
    
    -- Insert review
    MySQL.insert.await(
        'INSERT INTO taxi_reviews (review_id, ride_id, passenger_cid, driver_cid, rating, comment) VALUES (?, ?, ?, ?, ?, ?)',
        { review_id, ride_id, user_id, driver_id, rating, comment or '' }
    )
    print(('[qbx_taxijob] [DB] Created review: %s'):format(review_id))
    
    -- Update driver stats
    local stats = MySQL.single.await('SELECT * FROM taxi_driver_stats WHERE driver_cid = ? LIMIT 1', { driver_id })
    
    if stats then
        -- Running average calculation
        local new_total_reviews = stats.total_reviews + 1
        local new_total_rating_sum = stats.total_rating_sum + rating
        local new_average_rating = new_total_rating_sum / new_total_reviews
        
        -- Update rating breakdown
        local breakdown_field = ('rating_%s_count'):format(rating)
        
        MySQL.update.await(
            ('UPDATE taxi_driver_stats SET total_reviews = ?, total_rating_sum = ?, average_rating = ?, %s = %s + 1 WHERE driver_cid = ?'):format(breakdown_field, breakdown_field),
            { new_total_reviews, new_total_rating_sum, new_average_rating, driver_id }
        )
        
        -- Also update drivers table for quick access
        MySQL.update.await('UPDATE taxi_drivers SET rating = ? WHERE citizenid = ?', { new_average_rating, driver_id })
        
        print(('[qbx_taxijob] [DB] Updated driver stats - New avg: %.2f (%d reviews)'):format(new_average_rating, new_total_reviews))
    else
        -- Create stats entry
        MySQL.insert.await(
            'INSERT INTO taxi_driver_stats (driver_cid, total_reviews, total_rating_sum, average_rating, rating_1_count, rating_2_count, rating_3_count, rating_4_count, rating_5_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { driver_id, 1, rating, rating, 
              rating == 1 and 1 or 0,
              rating == 2 and 1 or 0,
              rating == 3 and 1 or 0,
              rating == 4 and 1 or 0,
              rating == 5 and 1 or 0
            }
        )
        
        MySQL.update.await('UPDATE taxi_drivers SET rating = ? WHERE citizenid = ?', { rating, driver_id })
        print(('[qbx_taxijob] [DB] Created driver stats for: %s'):format(driver_id))
    end
    
    return review_id
end

function DB.getDriverReviews(driver_id, limit)
    limit = limit or 10
    
    local results = MySQL.query.await(
        'SELECT * FROM taxi_reviews WHERE driver_cid = ? ORDER BY created_at DESC LIMIT ?',
        { driver_id, limit }
    )
    
    return results or {}
end

function DB.getDriverStats(driver_id)
    local result = MySQL.single.await('SELECT * FROM taxi_driver_stats WHERE driver_cid = ? LIMIT 1', { driver_id })
    return result
end

function DB.getPassengerName(user_id)
    local name = MySQL.scalar.await('SELECT name FROM taxi_users WHERE citizenid = ? LIMIT 1', { user_id })
    return name or 'Anonymous'
end

-- Fetch a ride by ride_id
function DB.getRide(ride_id)
    if not ride_id then return nil end
    local row = MySQL.single.await('SELECT * FROM taxi_rides WHERE ride_id = ? LIMIT 1', { ride_id })
    return row
end

-- Update fare for a ride
function DB.updateRideFare(ride_id, amount)
    if not ride_id then return end
    MySQL.update.await('UPDATE taxi_rides SET fare = ? WHERE ride_id = ?', { tonumber(amount) or 0, ride_id })
end

-- Expose globally for use in server/main.lua without require
QbxTaxiDB = DB
DB.init()
