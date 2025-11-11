import React, { useState } from 'react'
import { Star, Phone, MessageCircle, Shield, Settings, HelpCircle, Clock, Car, DollarSign, User, Users, ChevronRight, Bell, CreditCard, Tag, AlertTriangle, MapPin } from 'lucide-react'

interface Driver {
  id: number
  name: string
  rating: number
  distance: string
  eta: string
  vehicle: string
  carType: string
  coords?: { x: number; y: number; z: number }
}

interface CustomerProfile {
  name: string
  phone: string
  citizenid: string
}

interface Props {
  visible: boolean
  onClose: () => void
  onlineDrivers?: Driver[]
  customerProfile?: CustomerProfile | null
}

export const CustomerTablet: React.FC<Props> = ({ visible, onClose, onlineDrivers: liveDrivers, customerProfile: liveProfile }) => {
  const [activeSection, setActiveSection] = useState<'home' | 'payment' | 'safety' | 'support' | 'settings'>('home')
  const [rideStatus, setRideStatus] = useState<'idle' | 'searching' | 'matched' | 'in-progress' | 'payment' | 'completed'>('idle')
  const [rating, setRating] = useState(0)
  const [autoPayEnabled, setAutoPayEnabled] = useState(true)
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<'debit' | 'cash'>('debit')

  if (!visible) return null

  // Use live customer profile from QBX Core, fallback to default
  const passengerProfile = {
    name: liveProfile?.name || 'Guest',
    phone: liveProfile?.phone || 'N/A',
    profilePic: 'https://avatar.iran.liara.run/public/boy'
  }
  
  // Use live drivers from server, no fallback to mock data
  const onlineDrivers = liveDrivers || []
  const currentDriver = {
    name: 'Michael Chen', rating: 4.9, trips: 1243, profilePic: 'https://avatar.iran.liara.run/public/boy',
    vehicle: 'Toyota Camry 2022', licensePlate: 'ABC 1234', eta: '3 min'
  }
  const fareBreakdown = { baseFare: 8.50, distance: 12.30, surge: 2.50, discount: -3.00, total: 20.30 }

  const Home = () => (
    <div className="space-y-6">
      {/* Profile Header */}
      <div className="glass-card p-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <img 
            src={passengerProfile.profilePic} 
            alt="Profile" 
            className="w-16 h-16 rounded-full border-[3px] border-cyan-500/30"
          />
          <div>
            <h2 className="text-xl font-bold text-white mb-1">{passengerProfile.name}</h2>
            <p className="text-sm text-gray-400 flex items-center gap-2">
              <Phone size={14} />
              {passengerProfile.phone}
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <button className="glass-button p-2" onClick={() => setActiveSection('settings')}>
            <Settings size={18} />
          </button>
        </div>
      </div>

      {/* Ride Booking Section */}
      <div className="glass-card p-5">
        <h3 className="text-lg font-bold text-white mb-3">Book Your Ride</h3>
        
        {/* Pickup Location */}
        <div className="mb-4">
          <label className="text-xs font-semibold text-gray-300 mb-2 block">Pickup Location</label>
          <div className="glass-input flex items-center gap-3 p-3">
            <div className="w-2.5 h-2.5 rounded-full bg-green-500"></div>
            <input 
              type="text" 
              placeholder="Enter your pickup location" 
              className="bg-transparent text-white text-sm flex-1 outline-none"
              defaultValue="123 Main Street, Downtown"
            />
          </div>
        </div>

        {/* Book Ride Button */}
        <button 
          onClick={() => setRideStatus('searching')}
          className="w-full bg-gradient-to-r from-cyan-600 to-blue-600 text-white py-3 rounded-xl font-bold text-base hover:shadow-lg hover:shadow-cyan-500/50 transition-all"
        >
          Book Ride Now
        </button>
      </div>

      {/* Available Drivers */}
      <div className="glass-card p-5">
        <div className="flex items-center justify-between mb-3">
          <h3 className="text-lg font-bold text-white flex items-center gap-2">
            <Users size={20} className="text-cyan-400" />
            Available Drivers Nearby
          </h3>
          <span className="glass-badge text-xs">{onlineDrivers.length} Online</span>
        </div>
        
        <div className="drivers-scrollable-container mt-3">
          {onlineDrivers.length > 0 ? (
            <div className="grid grid-cols-2 gap-4">
              {onlineDrivers.map(driver => (
                <div key={driver.id} className="glass-card p-4 hover:border-cyan-500/50 transition-all cursor-pointer">
                  <div className="flex items-start justify-between mb-2">
                    <div>
                      <h4 className="text-white text-sm font-semibold">{driver.name}</h4>
                      <p className="text-xs text-gray-400">{driver.vehicle}</p>
                    </div>
                    <div className="flex items-center gap-1 glass-badge text-xs">
                      <Star size={12} fill="#fbbf24" stroke="#fbbf24" />
                      <span>{driver.rating}</span>
                    </div>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-400">{driver.distance} away</span>
                    <span className="text-cyan-400 font-semibold">{driver.eta} ETA</span>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="glass-card p-8 text-center">
              <div className="w-16 h-16 rounded-full bg-gray-500/20 flex items-center justify-center mx-auto mb-4">
                <Car size={32} className="text-gray-400" />
              </div>
              <h4 className="text-white text-base font-semibold mb-2">No Drivers Available</h4>
              <p className="text-gray-400 text-sm">There are no taxi drivers online at the moment. Please check back later.</p>
            </div>
          )}
        </div>
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-3 gap-4">
        <button onClick={() => setActiveSection('payment')} className="glass-card p-4 hover:border-cyan-500/50 transition-all">
          <CreditCard size={24} className="text-cyan-400 mb-2" />
          <div className="text-white text-sm font-semibold">Payment</div>
          <div className="text-xs text-gray-400 mt-1">Manage methods</div>
        </button>
        <button onClick={() => setActiveSection('safety')} className="glass-card p-4 hover:border-cyan-500/50 transition-all">
          <Shield size={24} className="text-green-400 mb-2" />
          <div className="text-white text-sm font-semibold">Safety</div>
          <div className="text-xs text-gray-400 mt-1">Emergency & tips</div>
        </button>
        <button onClick={() => setActiveSection('support')} className="glass-card p-4 hover:border-cyan-500/50 transition-all">
          <HelpCircle size={24} className="text-blue-400 mb-2" />
          <div className="text-white text-sm font-semibold">Support</div>
          <div className="text-xs text-gray-400 mt-1">Help center</div>
        </button>
      </div>
    </div>
  )

  const RideInProgress = () => (
    <div className="space-y-4">
      <div className="glass-card p-4">
        <div className="flex items-center gap-4 mb-4">
          <img src={currentDriver.profilePic} alt="Driver" className="w-20 h-20 rounded-full border-4 border-cyan-500/30" />
          <div className="flex-1">
            <h2 className="text-xl font-bold text-white mb-1">{currentDriver.name}</h2>
            <div className="flex items-center gap-4 text-sm">
              <span className="flex items-center gap-1 text-yellow-400">
                <Star size={16} fill="#fbbf24" stroke="#fbbf24" />
                {currentDriver.rating}
              </span>
              <span className="text-gray-400">{currentDriver.trips} trips</span>
            </div>
          </div>
          <div className="flex gap-3">
            <button className="glass-button p-4"><Phone size={24} /></button>
            <button className="glass-button p-4"><MessageCircle size={24} /></button>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div className="glass-card p-4">
            <div className="text-gray-400 text-sm mb-1">Vehicle</div>
            <div className="text-white font-semibold">{currentDriver.vehicle}</div>
          </div>
          <div className="glass-card p-4">
            <div className="text-gray-400 text-sm mb-1">License Plate</div>
            <div className="text-white font-semibold">{currentDriver.licensePlate}</div>
          </div>
        </div>
      </div>

      <div className="glass-card p-4">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-bold text-white">Ride Status</h3>
          <span className="glass-badge bg-green-500/20 text-green-400">In Progress</span>
        </div>
        <div className="space-y-4">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-full bg-green-500/20 flex items-center justify-center">
              <Clock size={24} className="text-green-400" />
            </div>
            <div className="flex-1">
              <div className="text-white font-semibold">Estimated Arrival</div>
              <div className="text-gray-400">{currentDriver.eta}</div>
            </div>
          </div>
          <div className="glass-card p-4">
            <div className="flex items-center justify-between mb-2">
              <span className="text-gray-400">From</span>
              <MapPin size={16} className="text-green-500" />
            </div>
            <div className="text-white">123 Main Street, Downtown</div>
          </div>
        </div>
      </div>

      <button onClick={() => setRideStatus('payment')} className="w-full bg-gradient-to-r from-cyan-600 to-blue-600 text-white py-3 rounded-xl font-bold text-base hover:shadow-lg hover:shadow-cyan-500/50 transition-all">Simulate Ride Completed</button>
    </div>
  )

  const PaymentSelection = () => (
    <div className="space-y-4">
      <div className="glass-card p-5 text-center">
        <div className="w-20 h-20 rounded-full bg-green-500/20 flex items-center justify-center mx-auto mb-4">
          <Car size={48} className="text-green-400" />
        </div>
        <h2 className="text-xl font-bold text-white mb-2">Ride Completed!</h2>
        <p className="text-gray-400 mb-8">Please select your payment method</p>

        <div className="glass-card p-4 mb-4">
          <h3 className="text-xl font-bold text-white mb-4">Fare Summary</h3>
          <div className="space-y-3">
            <div className="flex justify-between text-gray-300"><span>Base Fare</span><span>${fareBreakdown.baseFare.toFixed(2)}</span></div>
            <div className="flex justify-between text-gray-300"><span>Distance</span><span>${fareBreakdown.distance.toFixed(2)}</span></div>
            <div className="flex justify-between text-gray-300"><span>Surge Pricing</span><span className="text-orange-400">+${fareBreakdown.surge.toFixed(2)}</span></div>
            <div className="flex justify-between text-green-400"><span>Discount</span><span>${fareBreakdown.discount.toFixed(2)}</span></div>
            <div className="h-px bg-white/10" />
            <div className="flex justify-between text-white text-xl font-bold"><span>Total</span><span>${fareBreakdown.total.toFixed(2)}</span></div>
          </div>
        </div>

        <div className="space-y-4 mb-4">
          <h3 className="text-lg font-bold text-white mb-4">Select Payment Method</h3>
          <button onClick={() => setSelectedPaymentMethod('debit')} className={`w-full glass-card p-4 transition-all ${selectedPaymentMethod === 'debit' ? 'border-2 border-cyan-500 bg-cyan-500/20' : 'border border-white/10 hover:border-cyan-500/50'}`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-blue-600 to-cyan-600 flex items-center justify-center"><CreditCard size={24} /></div>
                <div className="text-left"><div className="text-white font-semibold">Debit Card</div><div className="text-sm text-gray-400">•••• •••• •••• 8888</div></div>
              </div>
              <div className={`w-5 h-5 rounded-full border-2 ${selectedPaymentMethod === 'debit' ? 'border-cyan-500 bg-cyan-500' : 'border-white/20'}`} />
            </div>
          </button>
          <button onClick={() => setSelectedPaymentMethod('cash')} className={`w-full glass-card p-4 transition-all ${selectedPaymentMethod === 'cash' ? 'border-2 border-cyan-500 bg-cyan-500/20' : 'border border-white/10 hover:border-cyan-500/50'}`}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-green-600 to-emerald-600 flex items-center justify-center"><DollarSign size={24} /></div>
                <div className="text-left"><div className="text-white font-semibold">Cash Payment</div><div className="text-sm text-gray-400">Pay to driver</div></div>
              </div>
              <div className={`w-5 h-5 rounded-full border-2 ${selectedPaymentMethod === 'cash' ? 'border-cyan-500 bg-cyan-500' : 'border-white/20'}`} />
            </div>
          </button>
        </div>

        <button onClick={() => setRideStatus('completed')} className="w-full bg-gradient-to-r from-cyan-600 to-blue-600 text-white py-3 rounded-xl font-bold text-base hover:shadow-lg hover:shadow-cyan-500/50 transition-all">Proceed to Rate Driver</button>
      </div>
    </div>
  )

  const Rating = () => (
    <div className="space-y-4">
      <div className="glass-card p-5 text-center">
        <div className="w-20 h-20 rounded-full bg-green-500/20 flex items-center justify-center mx-auto mb-4"><Car size={48} className="text-green-400" /></div>
        <h2 className="text-xl font-bold text-white mb-2">Ride Completed!</h2>
        <p className="text-gray-400 mb-4">Thank you for riding with us</p>
        <div className="glass-card p-4 mb-4">
          <img src={currentDriver.profilePic} alt="Driver" className="w-20 h-20 rounded-full border-4 border-cyan-500/30 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-white mb-2">{currentDriver.name}</h3>
          <p className="text-gray-400 mb-4">How was your ride?</p>
          <div className="flex justify-center gap-3 mb-4">
            {[1,2,3,4,5].map(star => (
              <button key={star} onClick={() => setRating(star)} className="transition-transform hover:scale-110">
                <Star size={40} fill={star <= rating ? '#fbbf24' : 'none'} stroke={star <= rating ? '#fbbf24' : '#6b7280'} className="transition-colors" />
              </button>
            ))}
          </div>
          <textarea placeholder="Add a comment (optional)" className="w-full glass-input p-4 text-white rounded-2xl mb-4 resize-none" rows={3} />
        </div>
        <div className="glass-card p-4 mb-4 text-left">
          <h3 className="text-lg font-bold text-white mb-4">Fare Summary</h3>
          <div className="space-y-2"><div className="flex justify-between text-gray-300"><span>Total Fare</span><span className="text-white font-bold">${fareBreakdown.total.toFixed(2)}</span></div><div className="flex justify-between text-sm text-gray-400"><span>Payment Method</span><span>•••• 4242</span></div></div>
        </div>
        <button onClick={() => { setRideStatus('idle'); setRating(0); setActiveSection('home') }} className="w-full bg-gradient-to-r from-cyan-600 to-blue-600 text-white py-3 rounded-xl font-bold text-base">Submit Rating & Finish</button>
      </div>
    </div>
  )

  const Payment = () => (
    <div className="space-y-4">
      <button onClick={() => setActiveSection('home')} className="flex items-center gap-2 text-cyan-400 hover:text-cyan-300 transition-colors">
        <ChevronRight size={20} className="rotate-180" />
        Back to Home
      </button>

      {/* Promo Codes */}
      <div className="glass-card p-4">
        <h3 className="text-xl font-bold text-white mb-4">Promotions</h3>
        <div className="glass-input flex items-center gap-3 p-4 mb-4">
          <Tag size={20} className="text-gray-400" />
          <input 
            type="text" 
            placeholder="Enter promo code" 
            className="bg-transparent text-white flex-1 outline-none"
          />
        </div>
        <button className="w-full bg-gradient-to-r from-green-600 to-emerald-600 text-white py-3 rounded-2xl font-semibold">
          Apply Code
        </button>
      </div>
    </div>
  )

  const Safety = () => (
    <div className="space-y-4">
      <button onClick={() => setActiveSection('home')} className="flex items-center gap-2 text-cyan-400 hover:text-cyan-300 transition-colors">
        <ChevronRight size={20} className="rotate-180" />
        Back to Home
      </button>

      <div className="glass-card p-4">
        <h2 className="text-xl font-bold text-white mb-4 flex items-center gap-3">
          <Shield size={24} className="text-green-400" />
          Safety Center
        </h2>

        {/* Safety Tips */}
        <div className="space-y-4">
          <h3 className="text-lg font-bold text-white">Safety Tips</h3>
          
          <div className="glass-card p-4">
            <h4 className="text-white font-semibold mb-2">✓ Verify Your Driver</h4>
            <p className="text-sm text-gray-400">Always check the driver's name, photo, vehicle make, model, and license plate before getting in.</p>
          </div>

          <div className="glass-card p-4">
            <h4 className="text-white font-semibold mb-2">✓ Share Your Trip</h4>
            <p className="text-sm text-gray-400">Share your ride status with friends or family in real-time for added safety.</p>
          </div>

          <div className="glass-card p-4">
            <h4 className="text-white font-semibold mb-2">✓ Sit in the Back</h4>
            <p className="text-sm text-gray-400">Sitting in the back seat gives you more personal space and allows for a safer exit if needed.</p>
          </div>

          <div className="glass-card p-4">
            <h4 className="text-white font-semibold mb-2">✓ Trust Your Instincts</h4>
            <p className="text-sm text-gray-400">If something doesn't feel right, don't hesitate to end the ride and contact support.</p>
          </div>

          <div className="glass-card p-4">
            <h4 className="text-white font-semibold mb-2">✓ Buckle Up</h4>
            <p className="text-sm text-gray-400">Always wear your seatbelt during the ride for your safety.</p>
          </div>
        </div>

        {/* Emergency Contacts */}
        <div className="glass-card p-4 mt-6">
          <h3 className="text-lg font-bold text-white mb-4">Emergency Contacts</h3>
          <div className="space-y-3">
            <button className="w-full glass-button p-4 flex items-center justify-between">
              <span className="text-white font-semibold">Local Police</span>
              <Phone size={20} className="text-green-400" />
            </button>
          </div>
        </div>
      </div>
    </div>
  )

  const Support = () => (
    <div className="space-y-4">
      <button onClick={() => setActiveSection('home')} className="flex items-center gap-2 text-cyan-400 hover:text-cyan-300 transition-colors">
        <ChevronRight size={20} className="rotate-180" />
        Back to Home
      </button>

      <div className="glass-card p-4">
        <h2 className="text-xl font-bold text-white mb-4">Help & Support</h2>

        {/* FAQ Section */}
        <h3 className="text-xl font-bold text-white mb-4">Frequently Asked Questions</h3>
        <div className="space-y-3">
          {[
            "How do I change my payment method?",
            "What if I left something in the vehicle?",
            "How do I report an issue with my ride?",
            "Can I schedule a ride in advance?",
            "How does surge pricing work?",
            "How do I add a stop to my current ride?"
          ].map((question, index) => (
            <button key={index} className="w-full glass-card p-4 text-left hover:border-cyan-500/50 transition-all">
              <div className="flex items-center justify-between">
                <span className="text-white">{question}</span>
                <ChevronRight size={20} className="text-gray-400" />
              </div>
            </button>
          ))}
        </div>
      </div>
    </div>
  )

  const SettingsView = () => (
    <div className="space-y-4">
      <button onClick={() => setActiveSection('home')} className="flex items-center gap-2 text-cyan-400 hover:text-cyan-300 transition-colors">
        <ChevronRight size={20} className="rotate-180" />
        Back to Home
      </button>

      <div className="glass-card p-4">
        <h2 className="text-xl font-bold text-white mb-4">Settings</h2>

        {/* Profile Settings */}
        <div className="mb-4">
          <h3 className="text-lg font-bold text-white mb-4">Profile Settings</h3>
          <div className="space-y-4">
            <div className="glass-input p-4">
              <label className="text-sm text-gray-400 block mb-2">Full Name</label>
              <input 
                type="text" 
                defaultValue={passengerProfile.name}
                className="bg-transparent text-white w-full outline-none"
              />
            </div>
          </div>
        </div>

        {/* Ride Preferences */}
        <div className="mb-4">
          <h3 className="text-lg font-bold text-white mb-4">Ride Preferences</h3>
          <div className="space-y-3">
            {[
              { label: "Quiet Ride", enabled: false },
              { label: "No Smoking", enabled: true },
              { label: "Temperature Control", enabled: false },
              { label: "Music Preferences", enabled: false }
            ].map((pref, index) => (
              <div key={index} className="glass-card p-4 flex items-center justify-between">
                <span className="text-white">{pref.label}</span>
                <button className={`w-14 h-7 rounded-full transition-all ${pref.enabled ? 'bg-cyan-600' : 'bg-gray-600'}`}>
                  <div className={`w-5 h-5 rounded-full bg-white transition-all ${pref.enabled ? 'translate-x-8' : 'translate-x-1'}`}></div>
                </button>
              </div>
            ))}
          </div>
        </div>

        {/* Auto Pay */}
        <div className="glass-card p-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-bold text-white mb-1">Auto Pay</h3>
              <p className="text-sm text-gray-400">Automatically charge after rides</p>
            </div>
            <button 
              onClick={() => setAutoPayEnabled(!autoPayEnabled)}
              className={`w-16 h-8 rounded-full transition-all ${autoPayEnabled ? 'bg-cyan-600' : 'bg-gray-600'}`}
            >
              <div className={`w-6 h-6 rounded-full bg-white transition-all ${autoPayEnabled ? 'translate-x-9' : 'translate-x-1'}`}></div>
            </button>
          </div>
        </div>
      </div>
    </div>
  )

  return (
    <div className="fixed inset-0 z-[1000000] flex items-center justify-center p-4 bg-transparent pointer-events-none">
      {/* Tablet device mockup wrapper */}
      <div className="relative mx-auto border-gray-800 bg-gray-800 border-[12px] rounded-[2.2rem] w-full max-w-[1000px] h-[640px] shadow-2xl pointer-events-auto">
        {/* Side buttons (decorative) */}
        <div className="h-[36px] w-[3px] bg-gray-800 absolute left-[-16px] top-[120px] rounded-s-lg pointer-events-none"></div>
        <div className="h-[50px] w-[3px] bg-gray-800 absolute left-[-16px] top-[180px] rounded-s-lg pointer-events-none"></div>
        <div className="h-[50px] w-[3px] bg-gray-800 absolute left-[-16px] top-[240px] rounded-s-lg pointer-events-none"></div>
        <div className="h-[80px] w-[3px] bg-gray-800 absolute right-[-16px] top-[200px] rounded-e-lg pointer-events-none"></div>

        {/* Inner screen */}
        <div className="rounded-[2rem] overflow-hidden w-full h-full bg-transparent">
          <div className="tablet-frame" style={{maxWidth:'960px', margin:'0 auto', width:'100%', minHeight:'560px', height:'100%'}}>
            {/* Close Button */}
            <button onClick={onClose} className="close-button">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
            
            {/* Scrollable Content */}
            <div className="tablet-content p-6 space-y-6">
              {rideStatus === 'idle' && activeSection === 'home' && <Home />}
              {rideStatus === 'searching' && (
                <div className="flex items-center justify-center h-full">
                  <div className="text-center">
                    <div className="w-24 h-24 rounded-full border-4 border-cyan-500 border-t-transparent animate-spin mx-auto mb-4"></div>
                    <h2 className="text-xl font-bold text-white mb-2">Finding Your Ride...</h2>
                    <p className="text-gray-400">Connecting you with nearby drivers</p>
                    <button 
                      onClick={() => setRideStatus('matched')}
                      className="mt-8 bg-gradient-to-r from-cyan-600 to-blue-600 text-white py-3 px-8 rounded-2xl font-semibold"
                    >
                      Simulate Match
                    </button>
                  </div>
                </div>
              )}
              {(rideStatus === 'matched' || rideStatus === 'in-progress') && <RideInProgress />}
              {rideStatus === 'payment' && <PaymentSelection />}
              {rideStatus === 'completed' && <Rating />}
              {activeSection === 'payment' && <Payment />}
              {activeSection === 'safety' && <Safety />}
              {activeSection === 'support' && <Support />}
              {activeSection === 'settings' && <SettingsView />}
            </div>
          </div>
        </div>
      </div>

      <style>{`
        .tablet-frame {
          background: rgba(17, 24, 39, 0.95);
          backdrop-filter: blur(20px);
          border: 2px solid rgba(255, 255, 255, 0.15);
          border-radius: 32px;
          padding: 24px;
          font-size: 15px;
          line-height: 1.55;
          box-shadow: 0 24px 48px -12px rgba(0, 0, 0, 0.65),
                      inset 0 0 50px rgba(6, 182, 212, 0.12);
          position: relative;
          overflow: visible;
          display: flex;
          flex-direction: column;
        }

        .close-button {
          position: absolute;
          top: 16px;
          right: 16px;
          width: 36px;
          height: 36px;
          border-radius: 50%;
          background: rgba(239, 68, 68, 0.2);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(239, 68, 68, 0.3);
          color: #ef4444;
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          transition: all 0.3s ease;
          z-index: 1000;
        }

        .close-button:hover {
          background: rgba(239, 68, 68, 0.3);
          border-color: rgba(239, 68, 68, 0.5);
          transform: scale(1.1);
        }

        .tablet-content {
          width: 100%;
          flex: 1 1 auto;
          min-height: 0;
          overflow-y: auto;
          padding-right: 12px;
        }

        .tablet-content::-webkit-scrollbar {
          width: 8px;
        }

        .tablet-content::-webkit-scrollbar-track {
          background: rgba(255, 255, 255, 0.05);
          border-radius: 10px;
        }

        .tablet-content::-webkit-scrollbar-thumb {
          background: rgba(6, 182, 212, 0.6);
          border-radius: 10px;
        }

        .tablet-content::-webkit-scrollbar-thumb:hover {
          background: rgba(6, 182, 212, 0.8);
        }

        .glass-card {
          background: rgba(255, 255, 255, 0.05);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 20px;
          transition: all 0.3s ease;
        }

        .glass-card:hover {
          background: rgba(255, 255, 255, 0.08);
          border-color: rgba(6, 182, 212, 0.4);
        }

        .glass-button {
          background: rgba(255, 255, 255, 0.05);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 16px;
          color: white;
          transition: all 0.3s ease;
        }

        .glass-button:hover {
          background: rgba(255, 255, 255, 0.1);
          border-color: rgba(6, 182, 212, 0.5);
        }

        .glass-input {
          background: rgba(255, 255, 255, 0.05);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(255, 255, 255, 0.1);
          border-radius: 16px;
          transition: all 0.3s ease;
        }

        .glass-input:focus-within {
          border-color: rgba(6, 182, 212, 0.6);
          background: rgba(255, 255, 255, 0.08);
        }

        .glass-badge {
          background: rgba(6, 182, 212, 0.2);
          backdrop-filter: blur(10px);
          border: 1px solid rgba(6, 182, 212, 0.4);
          padding: 6px 16px;
          border-radius: 20px;
          font-size: 14px;
          font-weight: 600;
          color: #22d3ee;
        }

        .drivers-scrollable-container {
          max-height: 320px;
          overflow-y: auto;
          padding-right: 8px;
          margin-top: 10px;
        }

        .drivers-scrollable-container::-webkit-scrollbar {
          width: 6px;
        }

        .drivers-scrollable-container::-webkit-scrollbar-track {
          background: rgba(255, 255, 255, 0.05);
          border-radius: 10px;
        }

        .drivers-scrollable-container::-webkit-scrollbar-thumb {
          background: rgba(6, 182, 212, 0.6);
          border-radius: 10px;
        }

        .drivers-scrollable-container::-webkit-scrollbar-thumb:hover {
          background: rgba(6, 182, 212, 0.8);
        }
      `}</style>
    </div>
  )
}

export default CustomerTablet
