import React, { useState } from 'react'
import { Car, Navigation, DollarSign, User, MapPin, Clock, Check, X, ChevronRight, Star, TrendingUp, Award, Calendar } from 'lucide-react'

type Props = {
  visible: boolean
  rideInProgress: boolean
  onClose: () => void
}

export const DriverTablet: React.FC<Props> = ({ visible, onClose }) => {
  // Integrate UI only (no NUI calls). Local UI state is self-contained.
  const [currentView, setCurrentView] = useState<'dashboard' | 'accepted' | 'ongoing' | 'completed' | 'profile'>('dashboard')
  const [selectedRide, setSelectedRide] = useState<any>(null)
  const [rideStartTime, setRideStartTime] = useState<Date | null>(null)

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

  const [rideRequests, setRideRequests] = useState<any[]>([
    { id: 1, passenger: 'Sarah Johnson', rating: 4.8, pickup: '123 Market Street, Downtown', pickupDistance: '0.8 mi', destination: '456 Oak Avenue, Westside', fare: 18.5, avatar: 'https://avatar.iran.liara.run/public/girl' },
    { id: 2, passenger: 'Michael Chen', rating: 4.9, pickup: '789 Pine Road, Northside', pickupDistance: '1.2 mi', destination: '321 Elm Street, Eastside', fare: 22.0, avatar: 'https://avatar.iran.liara.run/public/boy' },
    { id: 3, passenger: 'Emily Davis', rating: 5.0, pickup: '555 Maple Drive, Southside', pickupDistance: '2.1 mi', destination: '888 Birch Lane, Central', fare: 15.75, avatar: 'https://avatar.iran.liara.run/public/girl' },
    { id: 4, passenger: 'James Wilson', rating: 4.7, pickup: '999 Cedar Court, Harbor District', pickupDistance: '0.5 mi', destination: '111 Walnut Way, Airport', fare: 35.0, avatar: 'https://avatar.iran.liara.run/public/boy' },
  ])

  // Dummy handlers to keep UI interactive locally (no external side-effects)
  const handleAcceptRide = (ride: any) => {
    setSelectedRide(ride)
    setCurrentView('accepted')
    setRideRequests((prev) => prev.filter((r) => r.id !== ride.id))
  }
  const handleDeclineRide = (rideId: number) => setRideRequests((prev) => prev.filter((r) => r.id !== rideId))
  const handleStartRide = () => {
    setRideStartTime(new Date())
    setCurrentView('ongoing')
  }
  const handleEndRide = () => setCurrentView('completed')
  const handlePaymentComplete = () => {
    setCurrentView('dashboard')
    setSelectedRide(null)
    setRideStartTime(null)
  }

  // Fully unmount the UI when not visible to avoid leftover overlay
  if (!visible) return null

  const DashboardView = () => (
    <div className="h-full flex flex-col overflow-hidden">
      <div className="flex items-center justify-between mb-6 flex-shrink-0">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-emerald-500 to-teal-500 flex items-center justify-center">
            <Car className="w-6 h-6 text-white" />
          </div>
          <div>
            <h1 className="text-xl font-bold text-white">Uthao - Available Rides</h1>
            <p className="text-gray-400 text-xs">Accept rides to start earning</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <button onClick={() => setCurrentView('profile')} className="bg-white/5 rounded-xl px-3 py-2 border border-white/10 hover:bg-white/10 transition-all duration-300 flex items-center gap-2 text-sm">
            <User className="w-5 h-5 text-white" />
            <span className="text-white font-medium">Profile</span>
          </button>
          <div className="flex items-center gap-2 bg-white/5 rounded-xl px-4 py-2 border border-white/10">
            <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
            <span className="text-white font-medium text-sm">Online</span>
          </div>
        </div>
      </div>

  <div className="flex-1 overflow-y-auto pr-1.5 space-y-3 custom-scrollbar min-h-0">
        {rideRequests.length === 0 ? (
          <div className="h-full flex items-center justify-center">
            <div className="text-center">
              <Car className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <p className="text-gray-400 text-lg">No rides available</p>
              <p className="text-gray-500 text-sm">New requests will appear here</p>
            </div>
          </div>
        ) : (
          rideRequests.map((ride) => (
            <div key={ride.id} className="bg-white/5 rounded-2xl p-5 border border-white/10 hover:bg-white/10 transition-all duration-300 flex-shrink-0">
              <div className="flex items-start mb-5">
                <div className="flex items-center gap-4">
                  <img src={ride.avatar} alt={ride.passenger} className="w-12 h-12 rounded-xl object-cover" />
                  <div>
                    <h3 className="text-white font-bold text-base">{ride.passenger}</h3>
                    <div className="flex items-center gap-2 mt-1">
                      <div className="flex items-center gap-1">
                        {[...Array(5)].map((_, i) => (
                          <svg key={i} className={`w-3.5 h-3.5 ${i < Math.floor(ride.rating) ? 'text-yellow-400' : 'text-gray-600'}`} fill="currentColor" viewBox="0 0 20 20">
                            <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                          </svg>
                        ))}
                        <span className="text-gray-400 text-xs ml-1">{ride.rating}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div className="space-y-3 mb-5">
                <div className="flex items-start gap-3">
                  <div className="w-9 h-9 rounded-lg bg-emerald-500/20 flex items-center justify-center flex-shrink-0">
                    <MapPin className="w-4 h-4 text-emerald-400" />
                  </div>
                  <div className="flex-1">
                    <p className="text-gray-400 text-xs mb-1">Pickup Location</p>
                    <p className="text-white font-medium text-sm">{ride.pickup}</p>
                    <div className="flex items-center gap-2 mt-2">
                      <Navigation className="w-3.5 h-3.5 text-teal-400" />
                      <span className="text-teal-400 font-medium text-xs">{ride.pickupDistance} away</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex gap-3">
                <button onClick={() => handleDeclineRide(ride.id)} className="flex-1 bg-red-500/20 hover:bg-red-500/30 text-red-400 font-semibold py-3 rounded-xl transition-all duration-300 flex items-center justify-center gap-1.5 border border-red-500/30 text-sm">
                  <X className="w-4 h-4" />
                  Decline
                </button>
                <button onClick={() => handleAcceptRide(ride)} className="flex-1 bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-semibold py-3 rounded-xl transition-all duration-300 flex items-center justify-center gap-1.5 shadow-md shadow-emerald-500/30 text-sm">
                  <Check className="w-4 h-4" />
                  Accept Ride
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  )

  const AcceptedView = () => (
    <div className="h-full flex flex-col overflow-hidden">
      <div className="flex items-center gap-3 mb-5 flex-shrink-0">
        <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-500 flex items-center justify-center">
          <Check className="w-7 h-7 text-white" />
        </div>
        <div>
          <h1 className="text-2xl font-bold text-white">Ride Accepted</h1>
          <p className="text-gray-400 text-sm">Navigate to pickup location</p>
        </div>
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
        <button onClick={handleStartRide} className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-emerald-500/30 text-lg">
          <Car className="w-5 h-5" />
          Start Ride
        </button>
      </div>
    </div>
  )

  const OngoingView = () => {
    const [elapsedTime, setElapsedTime] = useState(0)
    React.useEffect(() => {
      const id = setInterval(() => {
        if (rideStartTime) {
          const elapsed = Math.floor((Date.now() - rideStartTime.getTime()) / 1000)
          setElapsedTime(elapsed)
        }
      }, 1000)
      return () => clearInterval(id)
    }, [rideStartTime])
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
          <button onClick={handleEndRide} className="w-full bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-blue-500/30 text-lg">
            <Check className="w-5 h-5" />
            End Ride
          </button>
        </div>
      </div>
    )
  }

  const CompletedView = () => (
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
          <div className="border-t border-white/10 pt-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Base Fare</span>
              <span className="text-white font-semibold">${(selectedRide?.fare ? selectedRide.fare * 0.8 : 0).toFixed(2)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Service Fee</span>
              <span className="text-white font-semibold">${(selectedRide?.fare ? selectedRide.fare * 0.2 : 0).toFixed(2)}</span>
            </div>
            <div className="border-t border-white/10 pt-3 mt-3">
              <div className="flex items-center justify-between">
                <span className="text-white font-bold text-xl">Total Fare</span>
                <span className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-400">
                  ${selectedRide?.fare ? selectedRide.fare.toFixed(2) : '0.00'}
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

  const ProfileView = () => (
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
        <button onClick={() => setCurrentView('dashboard')} className="bg-white/5 rounded-xl px-4 py-2 border border-white/10 text-white hover:bg-white/10 transition-all duration-300">
          Back to Dashboard
        </button>
      </div>
      <div className="flex-1 overflow-y-auto pr-2 space-y-4 custom-scrollbar min-h-0">
        <div className="bg-white/5 rounded-3xl p-6 border border-white/10">
          <div className="flex items-center gap-5 mb-6">
            <img src={driverProfile.avatar} alt={driverProfile.name} className="w-20 h-20 rounded-2xl object-cover border-4 border-emerald-500" />
            <div className="flex-1">
              <h2 className="text-white font-bold text-2xl">{driverProfile.name}</h2>
              <div className="flex items-center gap-2 mt-2">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} className={`w-5 h-5 ${i < Math.floor(driverProfile.rating) ? 'text-yellow-400 fill-yellow-400' : 'text-gray-600'}`} />
                ))}
                <span className="text-white font-bold ml-1">{driverProfile.rating}</span>
                <span className="text-gray-400 text-sm">({driverProfile.totalRides} rides)</span>
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
              <p className="text-white font-bold text-2xl">${driverProfile.todayEarnings.toFixed(2)}</p>
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
            <h3 className="text-white font-bold text-xl">Performance</h3>
          </div>
          <div className="space-y-4">
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400">Completion Rate</span>
                <span className="text-white font-bold">{driverProfile.completionRate}%</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-gradient-to-r from-emerald-500 to-teal-500 h-2 rounded-full transition-all duration-500" style={{ width: `${driverProfile.completionRate}%` }} />
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400">Acceptance Rate</span>
                <span className="text-white font-bold">{driverProfile.acceptanceRate}%</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div className="bg-gradient-to-r from-blue-500 to-purple-500 h-2 rounded-full transition-all duration-500" style={{ width: `${driverProfile.acceptanceRate}%` }} />
              </div>
            </div>
          </div>
        </div>
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
    </div>
  )

  return (
    <div className="tablet-container" style={{ display: visible ? 'grid' : 'none' }}>
      <div className="relative w-full max-w-[60rem] aspect-[16/10] bg-gradient-to-br from-gray-950 to-black rounded-[2.5rem] shadow-2xl border-[6px] border-gray-800 overflow-hidden">
        {/* Close */}
        <button onClick={onClose} aria-label="Close" className="absolute top-4 right-4 z-20 bg-white/10 hover:bg-white/20 text-white rounded-full w-9 h-9 flex items-center justify-center border border-white/20">✕</button>

        {/* Tablet camera */}
        <div className="absolute top-1/2 left-6 -translate-y-1/2 w-3 h-3 bg-gray-700 rounded-full z-10" />

        <div className="h-full w-full p-6">
          <div className="h-full bg-gradient-to-br from-gray-900/50 to-gray-800/50 rounded-3xl p-6 overflow-hidden">
            {currentView === 'dashboard' && <DashboardView />}
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
