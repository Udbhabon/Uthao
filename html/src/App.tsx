import { useEffect, useState } from 'react'
import { nuiSend } from './nui'

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

  return (
    <div className="container" style={{ display: visible ? 'block' : 'none' }}>
      <div className="g5-meter" data-started={meterStarted ? 'true' : 'false'}>
        <div className="panel">
          <div className="box box1">
            <button className="toggle-meter-btn" data-active={meterStarted ? 'true' : 'false'} onClick={meterToggle} aria-pressed={meterStarted}>
              <span className="status-dot" />
              <span className="status-text">{meterStarted ? 'Started' : 'Stopped'}</span>
            </button>
          </div>
          <div className="box box2">
            <span id="total-price">$ {currentFare.toFixed(2)}</span>
            <span id="total-price-label">Total Fare</span>
          </div>
          <div className="bottom-row">
            <div className="box box3">
              <span id="total-price-per-100m">$ {Number(defaultPrice).toFixed(2)}</span>
              <span id="total-price-per-100m-label">Price / mile</span>
            </div>
            <div className="box box4">
              <span id="total-distance">{distance.toFixed(2)} mi</span>
              <span id="total-distance-label">Total Distance</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
