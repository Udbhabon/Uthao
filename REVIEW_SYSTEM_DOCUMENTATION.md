# Review System Implementation Documentation

## Overview
Complete review and rating system for QBX Taxi Job that allows passengers to rate drivers (1-5 stars) with optional comments. Driver statistics are stored and displayed in their profile with running average calculation for performance optimization.

## Database Schema

### Tables Added to `data/db.json`

#### 1. `reviews` Table
Stores individual reviews submitted by passengers.

```lua
{
  "review_id": string,          -- Unique identifier (UUID)
  "user_id": string,            -- Passenger citizen ID (foreign key)
  "driver_id": string,          -- Driver citizen ID (foreign key)
  "ride_id": string,            -- Ride ID (foreign key)
  "rating": number (1-5),       -- Star rating
  "comment": string,            -- Optional comment
  "timestamp": string           -- ISO 8601 timestamp
}
```

#### 2. `driver_stats` Table
Stores aggregated driver statistics for efficient retrieval.

```lua
{
  "driver_id": string,          -- Driver citizen ID (primary key)
  "total_reviews": number,      -- Count of all reviews
  "average_rating": number,     -- Running average rating
  "total_rating_sum": number,   -- Sum of all ratings (for running avg)
  "ratings_breakdown": {
    "1": number,                -- Count of 1-star reviews
    "2": number,                -- Count of 2-star reviews
    "3": number,                -- Count of 3-star reviews
    "4": number,                -- Count of 4-star reviews
    "5": number                 -- Count of 5-star reviews
  }
}
```

## Server Implementation

### Database Functions (`server/db.lua`)

#### `addReview(user_id, driver_id, ride_id, rating, comment)`
- **Lines**: 232-304
- **Purpose**: Add a new review and update driver statistics
- **Algorithm**: Uses running average formula for O(1) rating updates
  ```lua
  new_average = (total_rating_sum + new_rating) / (total_reviews + 1)
  ```
- **Side Effects**: 
  - Creates/updates `driver_stats` entry
  - Increments `ratings_breakdown[rating]`
  - Updates `drivers` table `average_rating` field
- **Returns**: Review ID or nil on error

#### `getDriverReviews(driver_id, limit)`
- **Lines**: 306-326
- **Purpose**: Fetch driver reviews sorted by timestamp
- **Parameters**: 
  - `driver_id`: Driver citizen ID
  - `limit`: Max reviews to return (default: 10)
- **Returns**: Array of review objects sorted newest first

#### `getDriverStats(driver_id)`
- **Lines**: 328-332
- **Purpose**: Get comprehensive driver statistics
- **Returns**: Full `driver_stats` object with rating breakdown

#### `getPassengerName(user_id)`
- **Lines**: 334-338
- **Purpose**: Lookup passenger name from users table
- **Returns**: Passenger name string

### Server Callbacks (`server/main.lua`)

#### `qbx_taxijob:server:SubmitReview`
- **Lines**: 807-842
- **Purpose**: Handle review submission from passengers
- **Validation**:
  - Player existence check
  - Rating range validation (1-5)
- **Flow**:
  1. Validate source player
  2. Check rating is between 1-5
  3. Call `QbxTaxiDB.addReview()`
  4. Return success/failure response
- **Returns**: `{success: bool, reviewId: string, message: string}`

#### `qbx_taxijob:server:GetDriverStats`
- **Lines**: 844-903
- **Purpose**: Aggregate comprehensive driver statistics
- **Data Fetched**:
  - Driver stats (rating, breakdown)
  - Recent 10 reviews with passenger names
  - Total completed rides
  - Today's earnings
- **Review Enrichment**: Adds `passenger_name` field to each review
- **Returns**: 
  ```lua
  {
    rating = number,
    totalReviews = number,
    ratingsBreakdown = {1-5: counts},
    recentReviews = array of {rating, comment, timestamp, passenger_name},
    totalRides = number,
    todayEarnings = number
  }
  ```

### Event Modifications

#### `qbx_taxijob:client:RideCompleted`
- **Lines**: 329-336 in `server/main.lua`
- **Changes**: Added `driverCid` and `rideId` to event payload
- **Purpose**: Provide foreign keys for review submission

## Client Implementation

### Customer Tablet Bridge (`client/customer_tablet.lua`)

#### `customer:submitReview` NUI Callback
- **Lines**: 147-172
- **Purpose**: Bridge between React UI and server
- **Flow**:
  1. Receive review data from UI: `{driverCid, rideId, rating, comment}`
  2. Call server callback: `qbx_taxijob:server:SubmitReview`
  3. Show notification on success/failure
  4. Return success status to UI
- **Error Handling**: Try-catch with user-friendly notifications

### Driver Tablet Bridge (`client/tablet.lua`)

#### `driver:getStats` NUI Callback
- **Lines**: 97-109
- **Purpose**: Fetch driver statistics for profile display
- **Flow**:
  1. Call server callback: `qbx_taxijob:server:GetDriverStats`
  2. Return full stats object to React UI
- **Error Handling**: Returns error object if fetch fails

## React UI Implementation

### CustomerTablet.tsx

#### Interface Updates
- **Lines**: 20-28
- **Changes**: Added `driverCid?: string` and `rideId?: string` to `RideStatusUpdate` interface
- **Purpose**: Receive driver/ride info from server event

#### State Variables
- **Lines**: 48-51
- **Added**:
  ```typescript
  const [rideDriverCid, setRideDriverCid] = useState<string>('')
  const [rideId, setRideId] = useState<string>('')
  ```
- **Purpose**: Store driver/ride IDs for review submission

#### useEffect Modification
- **Purpose**: Capture driver/ride IDs when ride completes
- **Flow**: When `rideStatusUpdate.status === 'completed'`, store `driverCid` and `rideId` in state

#### Rating Component
- **Lines**: 479-588 (updated)
- **State**: 
  - `reviewComment`: Stores review text
  - `submittingReview`: Loading state during submission
- **Function**: `handleSubmitReview()`
  1. Validate rating (must be 1-5)
  2. Validate driver/ride IDs exist
  3. POST to `https://qbx_taxijob/customer:submitReview`
  4. Show loading state during submission
  5. Reset state and return to home on completion
- **UI Features**:
  - 5-star selection system
  - Optional comment textarea
  - Fare summary display
  - Disabled state during submission
  - "Submitting..." loading text

### DriverTablet.tsx

#### State Variables
- **Added**:
  ```typescript
  const [driverStats, setDriverStats] = useState<any>(null)
  const [loadingStats, setLoadingStats] = useState(false)
  ```

#### useEffect - Stats Fetching
- **Purpose**: Fetch stats when profile view opens
- **Trigger**: `visible && currentView === 'profile'`
- **Flow**: Call `nuiSend('driver:getStats')` and update state

#### ProfileView Component
- **Lines**: 460-620 (updated)
- **Dynamic Data**:
  - Rating: `driverStats?.rating` (fallback to mock data)
  - Total Rides: `driverStats?.totalRides`
  - Today's Earnings: `driverStats?.todayEarnings`
- **New Section**: **Rating Breakdown**
  - Displays 5-star to 1-star counts
  - Progress bars showing percentage distribution
  - Visual star icons for each rating tier
- **New Section**: **Recent Reviews**
  - Displays up to 10 most recent reviews
  - Shows passenger name, rating (star icons), comment
  - Displays date of review
  - Only rendered if reviews exist

## Data Flow

### Review Submission Flow
```
1. Driver ends ride (server)
   ↓
2. Server sends RideCompleted event with driverCid & rideId
   ↓
3. CustomerTablet receives event, stores driver/ride IDs
   ↓
4. Passenger rates driver (1-5 stars) + optional comment
   ↓
5. Submit button calls customer:submitReview NUI callback
   ↓
6. Client calls qbx_taxijob:server:SubmitReview callback
   ↓
7. Server validates and calls QbxTaxiDB.addReview()
   ↓
8. Database updates reviews table and driver_stats
   ↓
9. Client shows notification, returns to home
```

### Driver Stats Display Flow
```
1. Driver opens profile view in DriverTablet
   ↓
2. useEffect triggers driver:getStats NUI callback
   ↓
3. Client calls qbx_taxijob:server:GetDriverStats callback
   ↓
4. Server fetches driver_stats and recent reviews
   ↓
5. Server enriches reviews with passenger names
   ↓
6. Client receives comprehensive stats object
   ↓
7. React component displays rating, breakdown, reviews
```

## Performance Optimizations

### Running Average Calculation
- **Why**: Avoid recalculating average from all reviews on each submission
- **How**: Store `total_rating_sum` and `total_reviews` in driver_stats
- **Formula**: `new_avg = (total_sum + new_rating) / (total_reviews + 1)`
- **Complexity**: O(1) instead of O(n)

### Review Limits
- Default limit: 10 most recent reviews
- Sorted by timestamp descending
- Reduces data transfer and UI rendering load

### Stats Caching
- Driver stats stored in separate table
- No need to aggregate on every profile view
- Updated only when new review submitted

## Testing Checklist

- [ ] Submit 1-star review, verify driver_stats updates
- [ ] Submit 5-star review, verify driver_stats updates
- [ ] Submit review with comment, verify displays in driver profile
- [ ] Submit review without comment (optional field)
- [ ] Check rating breakdown percentages match actual distribution
- [ ] Verify passenger names display in driver review list
- [ ] Test multiple reviews, ensure running average is accurate
- [ ] Check reviews are sorted newest to oldest
- [ ] Verify today's earnings calculation
- [ ] Test review submission without driver/ride IDs (should gracefully fail)
- [ ] Verify resmon remains under 0.05ms (performance target)

## Future Enhancements

1. **Review Response System**: Allow drivers to respond to reviews
2. **Review Moderation**: Admin panel to remove inappropriate reviews
3. **Review Editing**: Allow passengers to edit/delete their reviews (within time limit)
4. **Weekly/Monthly Stats**: Expand stats to show trends over time
5. **Review Notifications**: Notify drivers when they receive a new review
6. **Review Incentives**: Reward high-rated drivers with bonuses
7. **Driver Verification Badge**: Award "Top Rated" badge for 4.8+ rating with 50+ reviews

## Files Modified

### Database
- `data/db.json` - Added reviews and driver_stats tables

### Server
- `server/db.lua` (107 lines added) - Database functions for reviews
- `server/main.lua` (96 lines added) - Callbacks for review submission and stats retrieval

### Client
- `client/customer_tablet.lua` (26 lines added) - NUI bridge for review submission
- `client/tablet.lua` (13 lines added) - NUI bridge for stats fetching

### UI
- `html/src/ui/tablet/CustomerTablet.tsx` - Review submission interface
- `html/src/ui/tablet/DriverTablet.tsx` - Dynamic stats and review display

### Build
- `html/dist/` - Compiled React app with review system

## Configuration
No new config values required. System uses existing database structure and QBX Core exports.

## Dependencies
- QBX Core (player data, notifications)
- Ox_lib (callbacks)
- JSON encoder/decoder (Lua built-in)

---

**Implementation Date**: January 2025
**Version**: 1.0.0
**Status**: ✅ Complete and Built
