import { useEffect, useState } from 'react'
import { nuiSend } from './nui'
import { Meter } from './ui/meter/Meter'
import { DriverTablet } from './ui/tablet/DriverTablet'
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

  useEffect(() => {
    const onMessage = (e: MessageEvent<any>) => {
      const data = e.data || {}
      if (data.action === 'openDriverTablet') {
        setTabletVisible(!!data.toggle)
      }
    }
    window.addEventListener('message', onMessage)
    return () => window.removeEventListener('message', onMessage)
  }, [])

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
        onClose={() => setTabletVisible(false)} 
      />
      <Toaster />
    </>
  )
}
