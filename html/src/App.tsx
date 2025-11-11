import { useEffect, useState } from 'react'
import { nuiSend } from './nui'
import { Meter } from './ui/meter/Meter'
import { DriverTablet } from './ui/tablet/DriverTablet'
import { CustomerTablet } from './ui/tablet/CustomerTablet'
import { Toaster } from '@/components/ui/toaster'

type MeterData = {
  defaultPrice: number
  currentFare?: number
  distanceTraveled?: number
}

export default function App() {
  const [visible, setVisible] = useState(false)
  const [meterStarted, setMeterStarted] = useState(false)
  const [defaultPrice, setDefaultPrice] = useState(0)
  const [currentFare, setCurrentFare] = useState(0)
  const [distance, setDistance] = useState(0)

  useEffect(() => {
    // Signal to the client script that the NUI is mounted and ready
    nuiSend('ping').catch(() => {})

    const onMessage = (e: MessageEvent<any>) => {
      const data = e.data || {}
      switch (data.action) {
        case 'openMeter': {
          const toggle = !!data.toggle
          if (toggle) {
            const meterData: MeterData = data.meterData || { defaultPrice: 0 }
            setDefaultPrice(Number(meterData.defaultPrice || 0))
            setVisible(true)
          } else {
            setVisible(false)
          }
          break
        }
        case 'toggleMeter': {
          meterToggle()
          break
        }
        case 'updateMeter': {
          const meterData: MeterData = data.meterData || {}
          setCurrentFare(Number(meterData.currentFare || 0))
          setDistance(Number(meterData.distanceTraveled || 0))
          break
        }
        case 'resetMeter': {
          setCurrentFare(0)
          setDistance(0)
          setMeterStarted(false)
          break
        }
      }
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  async function meterToggle() {
    const willEnable = !meterStarted
    await nuiSend('enableMeter', { enabled: willEnable })
    setMeterStarted(willEnable)
  }

  const [tabletVisible, setTabletVisible] = useState(false)
  const [customerTabletVisible, setCustomerTabletVisible] = useState(false)
  const [onlineDrivers, setOnlineDrivers] = useState<any[]>([])
  const [customerProfile, setCustomerProfile] = useState<any>(null)

  const [rideStatus, setRideStatus] = useState<any>(null)

  useEffect(() => {
    const onMessage = (e: MessageEvent<any>) => {
      const data = e.data || {}
      switch (data.action) {
        case 'openDriverTablet':
          setTabletVisible(!!data.toggle)
          break
        case 'openCustomerTablet':
          setCustomerTabletVisible(!!data.toggle)
          if (data.toggle && data.customerProfile) {
            setCustomerProfile(data.customerProfile)
          }
          break
        case 'updateOnlineDrivers':
          setOnlineDrivers(data.drivers || [])
          break
        case 'rideAccepted':
          setRideStatus({ status: 'accepted', driver: data.driverName, driverSrc: data.driverSrc })
          break
        case 'rideRejected':
          setRideStatus({ status: 'rejected', reason: data.reason })
          break
      }
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

  // Close tablet: notify client (release NUI focus) then hide locally
  const closeTablet = async () => {
    try { await nuiSend('closeDriverTablet') } catch {}
    try { await nuiSend('tablet:close') } catch {}
    setTabletVisible(false)
  }
  const closeCustomerTablet = async () => {
    try { await nuiSend('closeCustomerTablet') } catch {}
    try { await nuiSend('customerTablet:close') } catch {}
    setCustomerTabletVisible(false)
  }

  // Allow ESC to close the tablet and release focus
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        if (tabletVisible) {
          e.preventDefault()
          closeTablet()
        } else if (customerTabletVisible) {
          e.preventDefault()
          closeCustomerTablet()
        }
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [tabletVisible, customerTabletVisible])

  return (
    <>
      <Meter
        visible={visible}
        meterStarted={meterStarted}
        currentFare={currentFare}
        distance={distance}
        defaultPrice={defaultPrice}
        onToggle={meterToggle}
      />
      <DriverTablet
        visible={tabletVisible}
        rideInProgress={meterStarted}
        onClose={closeTablet}
      />
      <CustomerTablet
        visible={customerTabletVisible}
        onClose={closeCustomerTablet}
        onlineDrivers={onlineDrivers}
        customerProfile={customerProfile}
        rideStatusUpdate={rideStatus}
        onRideStatusHandled={() => setRideStatus(null)}
      />
      <Toaster />
    </>
  )
}
