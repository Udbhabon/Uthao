import React, { useEffect, useState } from 'react'
import { Navigation, MapPin, Clock, DollarSign, Zap } from 'lucide-react'

interface MeterProps {
  visible: boolean
  meterStarted: boolean
  currentFare: number
  distance: number
  defaultPrice: number
  onToggle: () => void
}

export const Meter: React.FC<MeterProps> = ({ visible, meterStarted, currentFare, distance }) => {
  const [simFare, setSimFare] = useState(0)
  const [simDistance, setSimDistance] = useState(0)
  const [duration, setDuration] = useState(0)
  const [speed, setSpeed] = useState(0)

  const BASE_FARE = 2.50
  const PER_KM_RATE = 1.20
  const PER_MINUTE_RATE = 0.35

  const useSimulation = meterStarted && currentFare === 0 && distance === 0

  useEffect(() => {
    if (!meterStarted) {
      setSimFare(0)
      setSimDistance(0)
      setDuration(0)
      setSpeed(0)
      return
    }
    if (!useSimulation) return
    const interval = setInterval(() => {
      setSimDistance(prev => +(prev + 0.01).toFixed(2))
      setDuration(prev => prev + 1)
      setSpeed(Math.floor(Math.random() * 30) + 20)
    }, 1000)
    return () => clearInterval(interval)
  }, [meterStarted, useSimulation])

  useEffect(() => {
    if (!meterStarted || !useSimulation) return
    const fare = BASE_FARE + (simDistance * PER_KM_RATE) + (duration / 60 * PER_MINUTE_RATE)
    setSimFare(fare)
  }, [meterStarted, useSimulation, simDistance, duration])

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  const displayedFare = useSimulation ? simFare : currentFare
  const displayedDistance = useSimulation ? simDistance : distance

  if (!visible) return null

  return (
    <div className="pointer-events-none fixed bottom-4 right-4 z-[999999] w-[600px] max-w-[90vw]">
      <div className="pointer-events-auto w-full bg-gradient-to-br from-slate-800/95 to-slate-900/95 backdrop-blur-xl rounded-3xl shadow-2xl border border-cyan-500/30 overflow-hidden">
        <div className="bg-gradient-to-r from-slate-700 to-slate-800 px-4 py-2.5 border-b border-cyan-500/20">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="bg-cyan-500/20 p-1.5 rounded-lg backdrop-blur-sm border border-cyan-500/30">
                <Navigation className="w-4 h-4 text-cyan-400" />
              </div>
              <div>
                <h1 className="text-white font-bold text-sm leading-none">Taxi Meter</h1>
                <p className="text-slate-300 text-[10px]">{meterStarted ? 'Active Trip' : 'Idle'}</p>
              </div>
            </div>
            <div className={`px-2.5 py-1 rounded-full text-[10px] font-semibold ${meterStarted ? 'bg-cyan-400 text-slate-900' : 'bg-slate-600 text-slate-200'}`}>{meterStarted ? 'RUNNING' : 'IDLE'}</div>
          </div>
        </div>
        <div className="p-4">
          <div className="grid grid-cols-12 gap-4">
            <div className="col-span-7 flex flex-col justify-center space-y-3">
              <div className="text-center pb-3 border-b border-cyan-500/20">
                <p className="text-slate-400 text-[10px] font-medium uppercase tracking-wide mb-1">Current Fare</p>
                <div className="relative">
                  <div className="text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500 mb-0.5 select-none">
                    ${displayedFare.toFixed(2)}
                  </div>
                  {meterStarted && (
                    <div className="absolute inset-0 bg-gradient-to-r from-cyan-400/20 to-blue-500/20 blur-2xl animate-pulse" />
                  )}
                </div>
              </div>
              <div className="grid grid-cols-3 gap-2">
                <div className="bg-gradient-to-br from-blue-500/10 to-blue-600/10 border border-blue-500/20 rounded-xl p-2.5 backdrop-blur-sm">
                  <div className="flex items-center gap-1 mb-1">
                    <MapPin className="w-3.5 h-3.5 text-blue-400" />
                    <p className="text-blue-300 text-[10px] font-medium">Distance</p>
                  </div>
                  <p className="text-white text-lg font-bold">{displayedDistance.toFixed(2)}</p>
                  <p className="text-blue-300 text-[10px]">km</p>
                </div>
                <div className="bg-gradient-to-br from-green-500/10 to-green-600/10 border border-green-500/20 rounded-xl p-2.5 backdrop-blur-sm">
                  <div className="flex items-center gap-1 mb-1">
                    <Clock className="w-3.5 h-3.5 text-green-400" />
                    <p className="text-green-300 text-[10px] font-medium">Time</p>
                  </div>
                  <p className="text-white text-lg font-bold">{formatTime(duration)}</p>
                  <p className="text-green-300 text-[10px]">mm:ss</p>
                </div>
                <div className="bg-gradient-to-br from-orange-500/10 to-orange-600/10 border border-orange-500/20 rounded-xl p-2.5 backdrop-blur-sm">
                  <div className="flex items-center gap-1 mb-1">
                    <Zap className="w-3.5 h-3.5 text-orange-400" />
                    <p className="text-orange-300 text-[10px] font-medium">Speed</p>
                  </div>
                  <p className="text-white text-lg font-bold">{speed}</p>
                  <p className="text-orange-300 text-[10px]">km/h</p>
                </div>
              </div>
            </div>
            <div className="col-span-5 flex flex-col justify-center">
              <div className="bg-slate-800/20 border border-slate-700/40 rounded-xl p-3 backdrop-blur-sm">
                <div className="flex items-center gap-1.5 mb-2">
                  <DollarSign className="w-3.5 h-3.5 text-cyan-400" />
                  <p className="text-cyan-300 text-[10px] font-semibold">Rate Info</p>
                </div>
                <div className="space-y-1.5 text-[10px]">
                  <div className="flex justify-between items-center">
                    <span className="text-slate-400">Base Fare:</span>
                    <span className="font-semibold text-white text-sm">${BASE_FARE.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between items-center border-t border-slate-700/40 pt-1.5">
                    <span className="text-slate-400">Per Kilometer:</span>
                    <span className="font-semibold text-white text-sm">${PER_KM_RATE.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between items-center border-t border-slate-700/40 pt-1.5">
                    <span className="text-slate-400">Per Minute:</span>
                    <span className="font-semibold text-white text-sm">${PER_MINUTE_RATE.toFixed(2)}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Meter

