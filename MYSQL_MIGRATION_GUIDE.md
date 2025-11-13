# QBX Taxi Job - JSON to MySQL Migration Guide

## 📋 Overview
This guide helps you migrate from the JSON-based database to MySQL using oxmysql.

---

## 🛠️ Prerequisites

1. **oxmysql** resource installed and configured
   - Download from: https://github.com/overextended/oxmysql
   - Configure `server.cfg` with MySQL connection details

2. **MySQL Server** running (MariaDB recommended)

3. **Database access** with CREATE TABLE permissions

---

## 📝 Step-by-Step Migration

### Step 1: Backup Your Data
**CRITICAL: Backup your JSON database before starting!**

```bash
copy "resources\qbx_taxijob\data\db.json" "resources\qbx_taxijob\data\db.json.backup"
```

### Step 2: Install Database Tables

1. Open your MySQL client (HeidiSQL, phpMyAdmin, etc.)
2. Select your FiveM database
3. Execute the SQL file: `sql/install.sql`

This will create 7 tables:
- `taxi_users` - Passenger records
- `taxi_drivers` - Driver profiles
- `taxi_vehicles` - Vehicle registrations
- `taxi_rides` - Ride history
- `taxi_transactions` - Payment records
- `taxi_reviews` - Driver reviews
- `taxi_driver_stats` - Aggregated driver statistics

### Step 3: Verify Tables Created

Run this query to check all tables exist:

```sql
SHOW TABLES LIKE 'taxi_%';
```

You should see 7 tables listed.

### Step 4: Configure oxmysql (if not already done)

Add to your `server.cfg` **BEFORE** starting qbx_taxijob:

```cfg
# MySQL Configuration
set mysql_connection_string "mysql://username:password@localhost/database_name?charset=utf8mb4"

# Optional: Enable debug mode
set mysql_debug 1

# Optional: Set slow query warning threshold (ms)
set mysql_slow_query_warning 150
```

### Step 5: Start/Restart the Resource

```
refresh
ensure qbx_taxijob
```

Watch the console for:
```
[qbx_taxijob] [DB] Checking MySQL database tables...
[qbx_taxijob] [DB] ✓ Table exists: taxi_users
[qbx_taxijob] [DB] ✓ Table exists: taxi_drivers
... (all 7 tables)
[qbx_taxijob] [DB] Database check complete
```

---

## 🔄 Data Migration (Optional)

If you have existing JSON data to migrate, you'll need to manually transfer it.

### Example: Migrate Drivers

```sql
-- Example INSERT for a driver from JSON
INSERT INTO taxi_drivers (citizenid, name, rating, total_rides, total_earnings) 
VALUES ('ABC12345', 'John Doe', 4.85, 156, 12450.00);
```

### Example: Migrate Reviews

```sql
-- Example INSERT for a review from JSON
INSERT INTO taxi_reviews (review_id, ride_id, passenger_cid, driver_cid, rating, comment)
VALUES ('review_ABC_1699999999', 'ride_123', 'XYZ98765', 'ABC12345', 5, 'Great driver!');

-- Then update driver stats
INSERT INTO taxi_driver_stats (driver_cid, total_reviews, total_rating_sum, average_rating, rating_5_count)
VALUES ('ABC12345', 1, 5, 5.00, 1)
ON DUPLICATE KEY UPDATE
    total_reviews = total_reviews + 1,
    total_rating_sum = total_rating_sum + 5,
    average_rating = total_rating_sum / total_reviews,
    rating_5_count = rating_5_count + 1;
```

---

## ⚙️ Configuration Changes

### Server Configuration

**Old** (`server.cfg`):
```cfg
ensure qbx_taxijob
```

**New** (ensure oxmysql starts first):
```cfg
ensure oxmysql
ensure qbx_taxijob
```

### Resource Dependencies

**fxmanifest.lua** now requires:
```lua
dependencies {
    'qbx_core',
    'oxmysql'  -- NEW
}
```

---

## 🧪 Testing Checklist

After migration, test these features:

- [ ] **Driver Duty**: Toggle duty on/off
- [ ] **Ride Booking**: Customer books a ride
- [ ] **Ride Acceptance**: Driver accepts a ride
- [ ] **Ride Completion**: Complete a ride and collect payment
- [ ] **Review System**: Submit a driver review
- [ ] **Driver Profile**: View driver stats and reviews in tablet
- [ ] **Payment Processing**: Both cash and debit payments work
- [ ] **Vehicle Assignment**: Vehicles are tracked correctly

---

## 🐛 Troubleshooting

### Error: "Undefined global `MySQL`"
**Solution**: Ensure oxmysql is started before qbx_taxijob
```cfg
ensure oxmysql
ensure qbx_taxijob
```

### Error: "Table 'taxi_users' doesn't exist"
**Solution**: Run `sql/install.sql` in your MySQL database

### Error: "Access denied for user"
**Solution**: Check your MySQL connection string in `server.cfg`
```cfg
set mysql_connection_string "mysql://user:pass@localhost/db?charset=utf8mb4"
```

### No data showing after migration
**Solution**: Data doesn't auto-migrate. You need to:
1. Keep the old JSON file as backup
2. Manually migrate important data using SQL INSERTs
3. Or start fresh (new drivers will register automatically)

### Performance issues with large datasets
**Solution**: Ensure indexes are created (they're in install.sql):
```sql
SHOW INDEX FROM taxi_reviews;
```

Should show indexes on `driver_cid`, `created_at`, etc.

---

## 📊 Performance Benefits

### JSON (Old)
- ❌ File I/O for every operation
- ❌ Full file read/write on every change
- ❌ No indexing or query optimization
- ❌ Single-threaded file access
- ❌ Limited to ~10k records before lag

### MySQL (New)
- ✅ Indexed queries (millisecond lookups)
- ✅ Concurrent read/write operations
- ✅ Query optimization and caching
- ✅ Scales to millions of records
- ✅ Built-in data integrity and relationships
- ✅ Backup and replication support

---

## 🔐 Security Improvements

- ✅ SQL injection prevention (parameterized queries)
- ✅ Transaction support (ACID compliance)
- ✅ Data validation at database level
- ✅ Referential integrity (foreign keys)
- ✅ User permissions and access control

---

## 📈 Database Maintenance

### Backup Database
```bash
mysqldump -u username -p database_name > qbx_taxijob_backup.sql
```

### Restore Database
```bash
mysql -u username -p database_name < qbx_taxijob_backup.sql
```

### Check Database Size
```sql
SELECT 
    table_name AS "Table",
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS "Size (MB)"
FROM information_schema.tables
WHERE table_schema = 'your_database_name'
AND table_name LIKE 'taxi_%'
ORDER BY (data_length + index_length) DESC;
```

### Optimize Tables (monthly maintenance)
```sql
OPTIMIZE TABLE taxi_rides, taxi_transactions, taxi_reviews;
```

---

## 📚 Additional Resources

- **oxmysql Documentation**: https://coxdocs.dev/oxmysql
- **MySQL Performance Tuning**: https://dev.mysql.com/doc/refman/8.0/en/optimization.html
- **QBX Core Documentation**: https://docs.qbox.re

---

## ✅ Migration Complete!

After successful migration:

1. ✅ All 7 database tables created
2. ✅ oxmysql dependency configured
3. ✅ Resource starts without errors
4. ✅ Basic functionality tested
5. ✅ Old JSON file backed up

Your QBX Taxi Job is now running on MySQL! 🎉

---

**Version**: 2.0.0
**Migration Date**: November 2025
**Status**: Production Ready
