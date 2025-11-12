import React, { useState } from 'react';
import { Car, Navigation, DollarSign, User, MapPin, Clock, Check, X, ChevronRight, Star, TrendingUp, Award, Calendar } from 'lucide-react';

const DriverTabletUI = () => {
  const [currentView, setCurrentView] = useState('accepted'); // accepted, ongoing, completed, profile - REMOVED dashboard
  const [rideStartTime, setRideStartTime] = useState(null);
  
  // Default ride data (since we're showing accepted screen by default)
  const [selectedRide] = useState({
    id: 1,
    passenger: 'Sarah Johnson',
    rating: 4.8,
    pickup: '123 Market Street, Downtown',
    pickupDistance: '0.8 mi',
    destination: '456 Oak Avenue, Westside',
    fare: 18.50,
    avatar: 'https://avatar.iran.liara.run/public/girl'
  });
  
  // Driver profile data
  const driverProfile = {
    name: 'John Anderson',
    avatar: 'https://avatar.iran.liara.run/public/boy',
    rating: 4.9,
    totalRides: 1247,
    experience: '3 years',
    joinDate: 'Jan 2022',
    vehicle: 'Toyota Camry 2021',
    licensePlate: 'ABC-1234',
    todayEarnings: 245.50,
    weekEarnings: 1580.00,
    monthEarnings: 6320.00,
    completionRate: 98,
    acceptanceRate: 95,
    badges: ['Top Rated', 'Safe Driver', '1000+ Rides']
  };
  


  const handleStartRide = () => {
    setRideStartTime(new Date());
    setCurrentView('ongoing');
  };

  const handleEndRide = () => {
    setCurrentView('completed');
  };

  const handlePaymentComplete = () => {
    setCurrentView('accepted'); // Changed from 'dashboard' to 'accepted'
    setRideStartTime(null);
  };

  // Accepted View
  const AcceptedView = () => (
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
        <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10 mb-5">
          <div className="flex items-center mb-6">
            <div className="flex items-center gap-4">
              <img 
                src={selectedRide?.avatar} 
                alt={selectedRide?.passenger}
                className="w-16 h-16 rounded-2xl object-cover"
              />
              <div>
                <h2 className="text-white font-bold text-xl">{selectedRide?.passenger}</h2>
                <div className="flex items-center gap-2 mt-1">
                  {[...Array(5)].map((_, i) => (
                    <svg key={i} className={`w-4 h-4 ${i < Math.floor(selectedRide?.rating) ? 'text-yellow-400' : 'text-gray-600'}`} fill="currentColor" viewBox="0 0 20 20">
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

        <button
          onClick={handleStartRide}
          className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-emerald-500/30 text-lg"
        >
          <Car className="w-5 h-5" />
          Start Ride
        </button>
      </div>
    </div>
  );

  // Ongoing Ride View
  const OngoingView = () => {
    const [elapsedTime, setElapsedTime] = useState(0);

    React.useEffect(() => {
      const interval = setInterval(() => {
        if (rideStartTime) {
          const elapsed = Math.floor((new Date() - rideStartTime) / 1000);
          setElapsedTime(elapsed);
        }
      }, 1000);
      return () => clearInterval(interval);
    }, [rideStartTime]);

    const formatTime = (seconds) => {
      const mins = Math.floor(seconds / 60);
      const secs = seconds % 60;
      return `${mins}:${secs.toString().padStart(2, '0')}`;
    };

    return (
      <div className="h-full flex flex-col overflow-hidden">
        <div className="flex items-center justify-between mb-5 flex-shrink-0">
          <div className="flex items-center gap-3">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center relative">
              <Car className="w-7 h-7 text-white" />
              <div className="absolute -top-1 -right-1 w-4 h-4 bg-emerald-500 rounded-full border-2 border-gray-900 animate-pulse"></div>
            </div>
            <div>
              <h1 className="text-2xl font-bold text-white">Ride in Progress</h1>
              <p className="text-gray-400 text-sm">Heading to destination</p>
            </div>
          </div>
          <div className="bg-white/5 backdrop-blur-xl rounded-2xl px-6 py-3 border border-white/10">
            <div className="flex items-center gap-2">
              <Clock className="w-5 h-5 text-teal-400" />
              <span className="text-white font-bold text-xl">{formatTime(elapsedTime)}</span>
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto pr-2 custom-scrollbar min-h-0">
          <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10 mb-5">
            <div className="flex items-center gap-4">
              <img 
                src={selectedRide?.avatar} 
                alt={selectedRide?.passenger}
                className="w-16 h-16 rounded-2xl object-cover"
              />
              <div>
                <h2 className="text-white font-bold text-xl">{selectedRide?.passenger}</h2>
                <p className="text-gray-400 text-sm mt-1">Passenger</p>
              </div>
            </div>
          </div>

          <button
            onClick={handleEndRide}
            className="w-full bg-gradient-to-r from-blue-500 to-purple-500 hover:from-blue-600 hover:to-purple-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-blue-500/30 text-lg"
          >
            <Check className="w-5 h-5" />
            End Ride
          </button>
        </div>
      </div>
    );
  };

  // Completed View
  const CompletedView = () => (
    <div className="h-full flex flex-col items-center justify-center">
      <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10 max-w-xl w-full">
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
              <img 
                src={selectedRide?.avatar} 
                alt={selectedRide?.passenger}
                className="w-14 h-14 rounded-2xl object-cover"
              />
              <div>
                <h2 className="text-white font-bold text-lg">{selectedRide?.passenger}</h2>
                <p className="text-gray-400 text-sm">Passenger</p>
              </div>
            </div>
          </div>

          <div className="border-t border-white/10 pt-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Base Fare</span>
              <span className="text-white font-semibold">${(selectedRide?.fare * 0.8).toFixed(2)}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-400">Service Fee</span>
              <span className="text-white font-semibold">${(selectedRide?.fare * 0.2).toFixed(2)}</span>
            </div>
            <div className="border-t border-white/10 pt-3 mt-3">
              <div className="flex items-center justify-between">
                <span className="text-white font-bold text-xl">Total Fare</span>
                <span className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 to-teal-400">
                  ${selectedRide?.fare.toFixed(2)}
                </span>
              </div>
            </div>
          </div>
        </div>

        <button
          onClick={handlePaymentComplete}
          className="w-full bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-600 hover:to-teal-600 text-white font-bold py-5 rounded-2xl transition-all duration-300 flex items-center justify-center gap-2 shadow-xl shadow-emerald-500/30 text-lg"
        >
          <DollarSign className="w-5 h-5" />
          Paid by Customer
        </button>
      </div>
    </div>
  );

  // Profile View
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
        <button
          onClick={() => setCurrentView('accepted')}
          className="bg-white/5 backdrop-blur-xl rounded-xl px-4 py-2 border border-white/10 text-white hover:bg-white/10 transition-all duration-300"
        >
          Back to Ride
        </button>
      </div>

      <div className="flex-1 overflow-y-auto pr-2 space-y-4 custom-scrollbar min-h-0">
        {/* Driver Info Card */}
        <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10">
          <div className="flex items-center gap-5 mb-6">
            <img 
              src={driverProfile.avatar} 
              alt={driverProfile.name}
              className="w-20 h-20 rounded-2xl object-cover border-4 border-emerald-500"
            />
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

        {/* Earnings Card */}
        <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10">
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

        {/* Performance Stats */}
        <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10">
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
                <div 
                  className="bg-gradient-to-r from-emerald-500 to-teal-500 h-2 rounded-full transition-all duration-500"
                  style={{ width: `${driverProfile.completionRate}%` }}
                ></div>
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="text-gray-400">Acceptance Rate</span>
                <span className="text-white font-bold">{driverProfile.acceptanceRate}%</span>
              </div>
              <div className="w-full bg-gray-700 rounded-full h-2">
                <div 
                  className="bg-gradient-to-r from-blue-500 to-purple-500 h-2 rounded-full transition-all duration-500"
                  style={{ width: `${driverProfile.acceptanceRate}%` }}
                ></div>
              </div>
            </div>
          </div>
        </div>

        {/* Badges */}
        <div className="bg-white/5 backdrop-blur-xl rounded-3xl p-6 border border-white/10">
          <div className="flex items-center gap-2 mb-5">
            <Award className="w-6 h-6 text-yellow-400" />
            <h3 className="text-white font-bold text-xl">Achievements</h3>
          </div>
          <div className="flex flex-wrap gap-3">
            {driverProfile.badges.map((badge, index) => (
              <div 
                key={index}
                className="bg-gradient-to-br from-yellow-500/20 to-orange-500/20 border border-yellow-500/30 rounded-xl px-4 py-2 flex items-center gap-2"
              >
                <Award className="w-4 h-4 text-yellow-400" />
                <span className="text-white font-semibold text-sm">{badge}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-transparent p-8 flex items-center justify-center">
      {/* Tablet Frame - Horizontal */}
      <div className="relative w-full max-w-6xl aspect-[16/10] bg-gradient-to-br from-gray-950 to-black rounded-[3rem] shadow-2xl border-8 border-gray-800 overflow-hidden">
        {/* Tablet Camera */}
        <div className="absolute top-1/2 left-6 transform -translate-y-1/2 w-3 h-3 bg-gray-700 rounded-full z-10"></div>
        
        {/* Scrollable Content Area */}
        <div className="h-full w-full p-8">
          <div className="h-full bg-gradient-to-br from-gray-900/50 to-gray-800/50 backdrop-blur-xl rounded-3xl p-8 overflow-hidden">
            {currentView === 'accepted' && <AcceptedView />}
            {currentView === 'ongoing' && <OngoingView />}
            {currentView === 'completed' && <CompletedView />}
            {currentView === 'profile' && <ProfileView />}
          </div>
        </div>

        {/* Tablet Home Button */}
        <div className="absolute bottom-6 left-1/2 transform -translate-x-1/2 w-16 h-2 bg-gray-700 rounded-full"></div>
      </div>

      <style>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 8px;
          height: 8px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: rgba(255, 255, 255, 0.05);
          border-radius: 10px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: rgba(255, 255, 255, 0.2);
          border-radius: 10px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: rgba(255, 255, 255, 0.3);
        }
      `}</style>
    </div>
  );
};

export default DriverTabletUI;
