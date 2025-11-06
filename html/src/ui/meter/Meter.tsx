import React from 'react'

interface MeterProps {
  visible: boolean
  meterStarted: boolean
  currentFare: number
  distance: number
  defaultPrice: number
  onToggle: () => void
}

export const Meter: React.FC<MeterProps> = ({ visible, meterStarted, currentFare, distance, defaultPrice, onToggle }) => {
  return (
    <div className="nui-meter-container" style={{ display: visible ? 'block' : 'none' }}>
      <div className="g5-meter" data-started={meterStarted ? 'true' : 'false'}>
        <div className="panel">
          <div className="box box1">
            <button className="toggle-meter-btn" data-active={meterStarted ? 'true' : 'false'} onClick={onToggle} aria-pressed={meterStarted}>
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
