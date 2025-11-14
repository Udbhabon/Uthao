import React, { useState, useEffect } from 'react'
import { Car, Navigation, DollarSign, User, MapPin, Clock, Check, X, ChevronRight, Star, TrendingUp, Award, Calendar } from 'lucide-react'
import { nuiSend } from '../../nui'

type Props = {
  visible: boolean
  rideInProgress: boolean
  onClose: () => void
  acceptedRide?: any | null
}

export const DriverTablet: React.FC<Props> = ({ visible, onClose, acceptedRide }) => {
  // Integrate UI only (no NUI calls). Local UI state is self-contained.
  const [currentView, setCurrentView] = useState<'accepted' | 'ongoing' | 'completed' | 'profile'>('accepted')
  const [rideStartTime, setRideStartTime] = useState<Date | null>(null)
  const [selectedRide, setSelectedRide] = useState<any>(null)
  const [isStartingRide, setIsStartingRide] = useState(false)
  const [canStartRide, setCanStartRide] = useState(false)
  const [startRideReason, setStartRideReason] = useState('Checking...')
  const [completedFare, setCompletedFare] = useState<{ fare: number; distance: number } | null>(null)
  
  // Update selectedRide when acceptedRide prop changes
  useEffect(() => {
    if (acceptedRide) {
      setSelectedRide(acceptedRide)
      console.log('[qbx_taxijob] [DriverTablet] Loaded ride:', acceptedRide)
    } else {
      setSelectedRide(null)
      console.log('[qbx_taxijob] [DriverTablet] No accepted ride')
    }
  }, [acceptedRide])
  
  // Check if ride can be started (vehicle validation)
  const checkCanStartRide = async () => {
    try {
      const result = await nuiSend<{ canStart: boolean; reason: string }>('tablet:checkCanStartRide')
      if (result) {
        setCanStartRide(result.canStart)
        setStartRideReason(result.reason)
        console.log('[qbx_taxijob] [DriverTablet] Can start ride:', result.canStart, '-', result.reason)
      }
    } catch (error) {
      console.error('[qbx_taxijob] [DriverTablet] Failed to check ride conditions:', error)
      setCanStartRide(false)
      setStartRideReason('Error checking conditions')
    }
  }
  
  // Check conditions when tablet opens and when ride is accepted
  useEffect(() => {
    if (visible && selectedRide && currentView === 'accepted') {
      // Initial check
      checkCanStartRide()
      
      // Poll every 2 seconds while on accepted view
      const interval = setInterval(checkCanStartRide, 2000)
      return () => clearInterval(interval)
    } else {
      setCanStartRide(false)
      setStartRideReason('No active ride')
    }
  }, [visible, selectedRide, currentView])

  // Driver stats state
  const [driverStats, setDriverStats] = useState<any>(null)
  const [loadingStats, setLoadingStats] = useState(false)

  // Fetch driver stats when profile view is opened
  useEffect(() => {
    if (visible && currentView === 'profile') {
      fetchDriverStats()
    }
  }, [visible, currentView])

  const fetchDriverStats = async () => {
    setLoadingStats(true)
    try {
      const result = await nuiSend<any>('driver:getStats')
      if (result) {
        console.log('[qbx_taxijob] [DriverTablet] Fetched driver stats:', result)
        setDriverStats(result)
      }
    } catch (error) {
      console.error('[qbx_taxijob] [DriverTablet] Failed to fetch driver stats:', error)
    } finally {
      setLoadingStats(false)
    }
  }

  const driverProfile = {
    name: 'John Anderson',
    avatar: 'https://avatar.iran.liara.run/public/boy',
    rating: 4.9,
    totalRides: 1247,
    experience: '3 years',
    joinDate: 'Jan 2022',
    vehicle: 'Toyota Camry 2021',
    licensePlate: 'ABC-1234',
    todayEarnings: 245.5,
    weekEarnings: 1580.0,
    monthEarnings: 6320.0,
    completionRate: 98,
    acceptanceRate: 95,
    badges: ['Top Rated', 'Safe Driver', '1000+ Rides'],
  }

  // Handler for starting ride (calls server logic via NUI)
  const handleStartRide = async () => {
    if (isStartingRide || !canStartRide) return // Prevent double-click and invalid starts
    
    setIsStartingRide(true)
    console.log('[qbx_taxijob] [DriverTablet] Starting ride...')
    
    try {
      const result = await nuiSend<{ success: boolean; message: string }>('tablet:startRide')
      
      // Only transition to ongoing view if server returns success
      if (result && result.success) {
        setRideStartTime(new Date())
        setCurrentView('ongoing')
        console.log('[qbx_taxijob] [DriverTablet] Ride started successfully:', result.message)
      } else {
        console.error('[qbx_taxijob] [DriverTablet] Failed to start ride:', result?.message || 'Unknown error')
        // Error notification already shown by server
        // Stay on accepted view
      }
    } catch (error) {
      console.error('[qbx_taxijob] [DriverTablet] Exception during start ride:', error)
    } finally {
      setIsStartingRide(false)
    }
  }
  
  const handleEndRide = async () => {
    console.log('[qbx_taxijob] [DriverTablet] Ending ride...')
    try {
      const result = await nuiSend<{ success: boolean; fare: number; distance: number }>('tablet:endRide')
      console.log('[qbx_taxijob] [DriverTablet] Received result from tablet:endRide:', result)
      
      if (result) {
        const fareData = { fare: result.fare || 0, distance: result.distance || 0 }
        setCompletedFare(fareData)
        console.log('[qbx_taxijob] [DriverTablet] Set completed fare:', fareData)
        console.log('[qbx_taxijob] [DriverTablet] Fare amount:', fareData.fare, 'Distance:', fareData.distance)
      } else {
        console.warn('[qbx_taxijob] [DriverTablet] No result from tablet:endRide')
      }
      setCurrentView('completed')
    } catch (error) {
      console.error('[qbx_taxijob] [DriverTablet] Failed to end ride:', error)
    }
  }
  
  const handlePaymentComplete = () => {
    // Clear local state and close NUI to release focus
    setCurrentView('accepted')
    setRideStartTime(null)
    setSelectedRide(null)
    setCompletedFare(null)
    onClose() // App will send focus-release NUI messages
  }

  // Fully unmount the UI when not visible to avoid leftover overlay
  if (!visible) return null

  const AcceptedView = () => {
    // Show empty state if no ride is accepted
    if (!selectedRide) {
      return (
        <div className="h-full flex flex-col items-center justify-center p-8">
          <div className="max-w-md text-center">
            <div className="w-24 h-24 rounded-full bg-gradient-to-br from-gray-700 to-gray-800 flex items-center justify-center mx-auto mb-6">
              <Car className="w-12 h-12 text-gray-500" />
            </div>
            <h2 className="text-2xl font-bold text-white mb-3">No Active Ride</h2>
            <p className="text-gray-400 text-lg mb-6">
              Accept a Ride Request to Manage Your Ride
            </p>
            <button
              onClick={() => setCurrentView('profile')}
              className="bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 text-white font-bold py-3 px-6 rounded-2xl transition-all duration-300 flex items-center gap-2 mx-auto shadow-xl shadow-blue-500/30"
            >
              <User className="w-5 h-5" />
              View Profile
            </button>
          </div>
        </div>
      )
    }

    // Show ride details if ride exists
    return (
      <div className="h-full flex flex-col overflow-hidden">
        <div className="flex items-center justify-between mb-5 flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-500 flex items-center justify-center">
              <Check className="w-7 h-7 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">Ride Accepted</h1>
              <p className="text-gray-400 text-sm">Navigate to pickup location</p>
            </div>
          </div>
          <button
            onClick={() => setCurrentView('profile')}
            className="bg-white/5 backdrop-blur-xl rounded-2xl px-4 py-3 border border-white/10 hover:bg-white/10 transition-all duration-300 flex items-center gap-2"
          >
            <User className="w-5 h-5 text-white" />
            <span className="text-white font-medium">Profile</span>
          </button>
        </div>
        <div className="flex-1 overflow-y-auto pr-2 custom-scrollbar min-h-0">
          <div className="bg-white/5 rounded-3xl p-6 border border-white/10 mb-5">
            <div className="flex items-center mb-6">
              <div className="flex items-center gap-4">
                <img src={selectedRide?.avatar} alt={selectedRide?.passenger} className="w-16 h-16 rounded-2xl object-cover" />
                <div>
                  <h2 className="text-white font-bold text-xl">{selectedRide?.passenger}</h2>
                  <div className="flex items-center gap-2 mt-1">
                    {[...Array(5)].map((_, i) => (
                      <svg key={i} className={`w-4 h-4 ${i < Math.floor(selectedRide?.rating || 0) ? 'text-yellow-400' : 'text-gray-600'}`} fill="currentColor" viewBox="0 0 20 20">
                        <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                      </svg>
                    ))}
                    <span className="text-gray-300 ml-2">{selectedRide?.rating}</span>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-black/20 rounded-2xl p-5 border border-white/5">
              <div className="flex items-start gap-3">
                <div className="w-11 h-11 rounded-xl bg-emerald-500/20 flex items-center justify-center flex-shrink-0">
                  <MapPin className="w-5 h-5 text-emerald-400" />
                </div>
                <div className="flex-1">
                  <p className="text-gray-400 text-xs mb-1">Pickup Location</p>
                  <p className="text-white font-semibold">{selectedRide?.pickup}</p>
                  <div className="flex items-center gap-2 mt-2">
                    <Navigation className="w-4 h-4 text-teal-400" />
                    <span className="text-teal-400 font-medium text-sm">{selectedRide?.pickupDistance} away</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          {/* Show condition status when button is disabled */}
          {!canStartRide && !isStartingRide && (
            <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-2xl p-4 mb-3 flex items-start gap-3">
              <div className="w-6 h-6 rounded-full bg-yellow-500/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                <span className="text-yellow-400 text-sm">!</span>
              </div>
              <div>
                <p className="text-yellow-400 font-semibold text-sm mb-1">Requirements Not Met</p>
                <p className="text-yellow-200/70 text-xs">
                  {startRideReason === 'Not in vehicle' && 'Get in your taxi vehicle'}
                  {startRideReason === 'Not in driver seat' && 'You must be in the driver seat'}
                  {startRideReason === 'Checking...' && 'Checking conditions...'}
                  {startRideReason === 'Ready' && 'All conditions met!'}
                  {!['Not in vehicle', 'Not in driver seat', 'Checking...', 'Ready'].includes(startRideReason) && startRideReason}
                </p>
              </div>
            </div>
          )}
          
          <button 
            onClick={handleStartRide} 
            disabled={isStartingRide || !canStartRide}
            className={`w-full font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 text-lg ${
              isStartingRide || !canStartRide
                ? 'bg-gray-700 text-gray-400 cursor-not-allowed opacity-60'
                : 'bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white shadow-xl shadow-emerald-500/30'
            }`}
          >
            {isStartingRide ? (
              <>
                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                Starting...
              </>
            ) : !canStartRide ? (
              <>
                <X className="w-5 h-5" />
                Cannot Start - {startRideReason}
              </>
            ) : (
              <>
                <Car className="w-5 h-5" />
                Start Ride
              </>
            )}
          </button>
        </div>
      </div>
    )
  }

  const OngoingView = () => {
    const [elapsedTime, setElapsedTime] = useState(0)
    const [showEndButton, setShowEndButton] = useState(false)
    
    React.useEffect(() => {
      const id = setInterval(() => {
        if (rideStartTime) {
          const elapsed = Math.floor((Date.now() - rideStartTime.getTime()) / 1000)
          setElapsedTime(elapsed)
          
          // Show end button after 60 seconds (1 minute)
          if (elapsed >= 60 && !showEndButton) {
            setShowEndButton(true)
          }
        }
      }, 1000)
      return () => clearInterval(id)
    }, [rideStartTime, showEndButton])
    
    const formatTime = (s: number) => {
      const m = Math.floor(s / 60)
      const sec = s % 60
      return `${m}:${sec.toString().padStart(2, '0')}`
    }
    return (
      <div className="h-full flex flex-col overflow-hidden">
        <div className="flex items-center justify-between mb-5 flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center relative">
              <Car className="w-7 h-7 text-white" />
              <div className="absolute -top-1 -right-1 w-4 h-4 bg-emerald-500 rounded-full border-2 border-gray-900 animate-pulse" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">Ride in Progress</h1>
              <p className="text-gray-400 text-sm">Heading to destination</p>
            </div>
          </div>
          <div className="bg-white/5 rounded-2xl px-6 py-3 border border-white/10">
            <div className="flex items-center gap-2">
              <Clock className="w-5 h-5 text-teal-400" />
              <span className="text-white font-bold text-xl">{formatTime(elapsedTime)}</span>
            </div>
          </div>
        </div>
        <div className="flex-1 overflow-y-auto pr-2 custom-scrollbar min-h-0">
          <div className="bg-white/5 rounded-3xl p-6 border border-white/10 mb-5">
            <div className="flex items-center gap-4">
              <img src={selectedRide?.avatar} alt={selectedRide?.passenger} className="w-16 h-16 rounded-2xl object-cover" />
              <div>
                <h2 className="text-white font-bold text-xl">{selectedRide?.passenger}</h2>
                <p className="text-gray-400 text-sm mt-1">Passenger</p>
              </div>
            </div>
          </div>
          
          {/* Show countdown message when button is not yet available */}
          {!showEndButton && (
            <div className="bg-blue-500/10 border border-blue-500/30 rounded-2xl p-4 mb-3 flex items-start gap-3">
              <div className="w-6 h-6 rounded-full bg-blue-500/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                <Clock className="w-4 h-4 text-blue-400" />
              </div>
              <div>
                <p className="text-blue-400 font-semibold text-sm mb-1">Minimum Ride Time</p>
                <p className="text-blue-200/70 text-xs">
                  End Ride button will be available after 1 minute ({60 - elapsedTime} seconds remaining)
                </p>
              </div>
            </div>
          )}
          
          {/* End Ride button - only show after 1 minute */}
          {showEndButton ? (
            <button 
              onClick={handleEndRide} 
              className="w-full bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-blue-500/30 text-lg"
            >
              <Check className="w-5 h-5" />
              End Ride
            </button>
          ) : (
            <button 
              disabled
              className="w-full bg-gray-700 text-gray-400 cursor-not-allowed opacity-60 font-bold py-5 rounded-2xl flex items-center justify-center gap-2 text-lg"
            >
              <Clock className="w-5 h-5" />
              End Ride (Available in {60 - elapsedTime}s)
            </button>
          )}
        </div>
      </div>
    )
  }

  const CompletedView = () => {
    // Use dynamic fare data from meter, fallback to ride data if not available
    const totalFare = completedFare?.fare ?? selectedRide?.fare ?? 0
    const distance = completedFare?.distance ?? 0
    const baseFare = totalFare * 0.8
    const serviceFee = totalFare * 0.2
    
    // Log on every render to debug
    React.useEffect(() => {
      console.log('[qbx_taxijob] [CompletedView] Rendered/Updated with:')
      console.log('  - completedFare:', JSON.stringify(completedFare))
      console.log('  - selectedRide?.fare:', selectedRide?.fare)
      console.log('  - totalFare:', totalFare)
      console.log('  - distance:', distance)
      console.log('  - baseFare:', baseFare)
      console.log('  - serviceFee:', serviceFee)
    }, [completedFare, selectedRide, totalFare, distance, baseFare, serviceFee])
    
    return (
      <div className="h-full flex flex-col items-center justify-center">
        <div className="bg-white/5 rounded-3xl p-6 border border-white/10 max-w-xl w-full">
          <div className="text-center mb-6">
            <div className="w-20 h-20 rounded-full bg-gradient-to-br from-emerald-500 to-teal-500 flex items-center justify-center mx-auto mb-4">
              <Check className="w-10 h-10 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">Ride Completed!</h1>
            <p className="text-gray-400">Great job on this trip</p>
          </div>
          <div className="bg-black/20 rounded-2xl p-6 border border-white/5 mb-6">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-3">
                <img src={selectedRide?.avatar} alt={selectedRide?.passenger} className="w-14 h-14 rounded-2xl object-cover" />
                <div>
                  <h2 className="text-white font-bold text-lg">{selectedRide?.passenger}</h2>
                  <p className="text-gray-400 text-sm">Passenger</p>
                </div>
              </div>
            </div>
            {distance > 0 && (
              <div className="mb-4 pb-4 border-b border-white/10">
                <div className="flex items-center gap-2">
                  <Navigation className="w-4 h-4 text-teal-400" />
                  <span className="text-gray-400 text-sm">Distance Traveled:</span>
                  <span className="text-white font-semibold">{distance.toFixed(2)} km</span>
                </div>
              </div>
            )}
            <div className="border-t border-white/10 pt-4 space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-gray-400">Base Fare</span>
                <span className="text-white font-semibold">${baseFare.toFixed(2)}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-gray-400">Service Fee</span>
                <span className="text-white font-semibold">${serviceFee.toFixed(2)}</span>
              </div>
              <div className="border-t border-white/10 pt-3 mt-3">
                <div className="flex items-center justify-between">
                  <span className="text-white font-bold text-xl">Total Fare</span>
                  <span className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-400">
                    ${totalFare.toFixed(2)}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <button onClick={handlePaymentComplete} className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-emerald-500/30 text-lg">
            <DollarSign className="w-5 h-5" />
            Paid by Customer
          </button>
        </div>
      </div>
    )
  }

  const ProfileView = () => {
  const displayRating = Number(driverStats?.rating ?? driverProfile.rating)
  const displayTotalRides = Number(driverStats?.totalRides ?? driverProfile.totalRides)
  const displayTodayEarnings = Number(driverStats?.todayEarnings ?? driverProfile.todayEarnings)
    const recentReviews = driverStats?.recentReviews || []
    const ratingsBreakdown = driverStats?.ratingsBreakdown || { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }

    return (
      <div className="h-full flex flex-col overflow-hidden">
        <div className="flex items-center justify-between mb-5 flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center">
              <User className="w-7 h-7 text-white" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">Driver Profile</h1>
              <p className="text-gray-400 text-sm">Your job statistics and details</p>
            </div>
          </div>
          <button onClick={() => setCurrentView('accepted')} className="bg-white/5 rounded-xl px-4 py-2 border border-white/10 text-white hover:bg-white/10 transition-all duration-300">
            Back to Ride
          </button>
        </div>
        {loadingStats ? (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-white text-lg">Loading statistics...</div>
          </div>
        ) : (
          <div className="flex-1 overflow-y-auto pr-2 space-y-4 custom-scrollbar min-h-0">
            <div className="bg-white/5 rounded-3xl p-6 border border-white/10">
              <div className="flex items-center gap-5 mb-6">
                <img src={driverProfile.avatar} alt={driverProfile.name} className="w-20 h-20 rounded-2xl object-cover border-4 border-emerald-500" />
                <div className="flex-1">
                  <h2 className="text-white font-bold text-2xl">{driverProfile.name}</h2>
                  <div className="flex items-center gap-2 mt-2">
                    {[...Array(5)].map((_, i) => (
                      <Star key={i} className={`w-5 h-5 ${i < Math.floor(displayRating) ? 'text-yellow-400 fill-yellow-400' : 'text-gray-600'}`} />
                    ))}
                    <span className="text-white font-bold ml-1">{displayRating.toFixed(1)}</span>
                    <span className="text-gray-400 text-sm">({displayTotalRides} rides)</span>
                  </div>
                </div>
                <div className="text-right">
                  <div className="text-emerald-400 text-sm font-medium">Member Since</div>
                  <div className="text-white font-bold text-lg">{driverProfile.joinDate}</div>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div className="bg-black/20 rounded-xl p-4 border border-white/5">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-blue-500/20 flex items-center justify-center">
                      <Car className="w-5 h-5 text-blue-400" />
                    </div>
                    <div>
                      <p className="text-gray-400 text-xs">Vehicle</p>
                      <p className="text-white font-semibold">{driverProfile.vehicle}</p>
                    </div>
                  </div>
                </div>
                <div className="bg-black/20 rounded-xl p-4 border border-white/5">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-lg bg-purple-500/20 flex items-center justify-center">
                      <Calendar className="w-5 h-5 text-purple-400" />
                    </div>
                    <div>
                      <p className="text-gray-400 text-xs">License Plate</p>
                      <p className="text-white font-semibold">{driverProfile.licensePlate}</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div className="bg-white/5 rounded-3xl p-6 border border-white/10">
              <div className="flex items-center gap-2 mb-5">
                <TrendingUp className="w-6 h-6 text-emerald-400" />
                <h3 className="text-white font-bold text-xl">Earnings</h3>
              </div>
              <div className="grid grid-cols-3 gap-4">
                <div className="bg-gradient-to-br from-emerald-500/20 to-teal-500/20 rounded-2xl p-4 border border-emerald-500/30">
                  <p className="text-emerald-400 text-xs font-medium mb-1">Today</p>
                  <p className="text-white font-bold text-2xl">${displayTodayEarnings.toFixed(2)}</p>
                </div>
                <div className="bg-gradient-to-br from-blue-500/20 to-purple-500/20 rounded-2xl p-4 border border-blue-500/30">
                  <p className="text-blue-400 text-xs font-medium mb-1">This Week</p>
                  <p className="text-white font-bold text-2xl">${driverProfile.weekEarnings.toFixed(2)}</p>
                </div>
                <div className="bg-gradient-to-br from-purple-500/20 to-pink-500/20 rounded-2xl p-4 border border-purple-500/30">
                  <p className="text-purple-400 text-xs font-medium mb-1">This Month</p>
                  <p className="text-white font-bold text-2xl">${driverProfile.monthEarnings.toFixed(2)}</p>
                </div>
              </div>
            </div>
            <div className="bg-white/5 rounded-3xl p-6 border border-white/10">
              <div className="flex items-center gap-2 mb-5">
                <Star className="w-6 h-6 text-yellow-400" />
                <h3 className="text-white font-bold text-xl">Rating Breakdown</h3>
              </div>
              <div className="space-y-3">
                {[5, 4, 3, 2, 1].map(stars => {
                  const count = ratingsBreakdown[stars] || 0
                  const total = Object.values(ratingsBreakdown).reduce((sum: number, val) => sum + (val as number), 0)
                  const percentage = total > 0 ? (count / total) * 100 : 0
                  
                  return (
                    <div key={stars}>
                      <div className="flex items-center justify-between mb-1">
                        <div className="flex items-center gap-2">
                          <span className="text-gray-400 text-sm w-12">{stars} Star{stars !== 1 ? 's' : ''}</span>
                          {[...Array(stars)].map((_, i) => (
                            <Star key={i} className="w-3 h-3 text-yellow-400 fill-yellow-400" />
                          ))}
                        </div>
                        <span className="text-white font-semibold text-sm">{count}</span>
                      </div>
                      <div className="w-full bg-gray-700 rounded-full h-2">
                        <div 
                          className="bg-gradient-to-r from-yellow-400 to-yellow-500 h-2 rounded-full transition-all duration-500" 
                          style={{ width: `${percentage}%` }} 
                        />
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
            {recentReviews.length > 0 && (
              <div className="bg-white/5 rounded-3xl p-6 border border-white/10">
                <div className="flex items-center gap-2 mb-5">
                  <Star className="w-6 h-6 text-yellow-400" />
                  <h3 className="text-white font-bold text-xl">Recent Reviews</h3>
                </div>
                <div className="space-y-4">
                  {recentReviews.map((review: any, index: number) => (
                    <div key={index} className="bg-black/20 rounded-xl p-4 border border-white/5">
                      <div className="flex items-start justify-between mb-2">
                        <div>
                          <div className="text-white font-semibold">{review.passenger_name || 'Anonymous'}</div>
                          <div className="flex items-center gap-1 mt-1">
                            {[...Array(5)].map((_, i) => (
                              <Star key={i} className={`w-4 h-4 ${i < review.rating ? 'text-yellow-400 fill-yellow-400' : 'text-gray-600'}`} />
                            ))}
                          </div>
                        </div>
                        <div className="text-gray-400 text-xs">
                          {new Date(review.timestamp).toLocaleDateString()}
                        </div>
                      </div>
                      {review.comment && (
                        <p className="text-gray-300 text-sm mt-2">{review.comment}</p>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
            <div className="bg-white/5 rounded-3xl p-6 border border-white/10">
              <div className="flex items-center gap-2 mb-5">
                <Award className="w-6 h-6 text-yellow-400" />
                <h3 className="text-white font-bold text-xl">Achievements</h3>
              </div>
              <div className="flex flex-wrap gap-3">
                {driverProfile.badges.map((badge, index) => (
                  <div key={index} className="bg-gradient-to-br from-yellow-500/20 to-orange-500/20 border border-yellow-500/30 rounded-xl px-4 py-2 flex items-center gap-2">
                    <Award className="w-4 h-4 text-yellow-400" />
                    <span className="text-white font-semibold text-sm">{badge}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    )
  }

  return (
    <div className="tablet-container" style={{ display: visible ? 'grid' : 'none' }}>
      <div className="relative w-full max-w-[60rem] aspect-[16/10] bg-gradient-to-br from-gray-950 to-black rounded-[2.5rem] shadow-2xl border-[6px] border-gray-800 overflow-hidden">
        {/* Close */}
        <button onClick={onClose} aria-label="Close" className="absolute top-4 right-4 z-20 bg-white/10 hover:bg-white/20 text-white rounded-full w-9 h-9 flex items-center justify-center border border-white/20">✕</button>

        {/* Tablet camera */}
        <div className="absolute top-1/2 left-6 -translate-y-1/2 w-3 h-3 bg-gray-700 rounded-full z-10" />

        <div className="h-full w-full p-6">
          <div className="h-full bg-gradient-to-br from-gray-900/50 to-gray-800/50 rounded-3xl p-6 overflow-hidden">
            {currentView === 'accepted' && <AcceptedView />}
            {currentView === 'ongoing' && <OngoingView />}
            {currentView === 'completed' && <CompletedView />}
            {currentView === 'profile' && <ProfileView />}
          </div>
        </div>

        <div className="absolute bottom-4 left-1/2 -translate-x-1/2 w-14 h-2 bg-gray-700 rounded-full" />
      </div>

      <style>{`
        .custom-scrollbar::-webkit-scrollbar { width: 8px; height: 8px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: rgba(255,255,255,0.05); border-radius: 10px; }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.2); border-radius: 10px; }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.3); }
      `}</style>
    </div>
  )
}
