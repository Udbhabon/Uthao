import React, { useEffect, useState } from 'react'
import { nuiSend } from '../../nui'

type Props = {
  visible: boolean
  rideInProgress: boolean
  onClose: () => void
}

export const DriverTablet: React.FC<Props> = ({ visible, rideInProgress, onClose }) => {
  // Local optimistic state so the UI switches immediately and
  // we never render both actions at the same time.
  const [localRideInProgress, setLocalRideInProgress] = useState<boolean>(!!rideInProgress)
  const [busy, setBusy] = useState<boolean>(false)

  useEffect(() => {
    // keep local state in sync when parent prop updates
    setLocalRideInProgress(!!rideInProgress)
  }, [rideInProgress])

  const startRide = async () => {
    if (busy || localRideInProgress) return
    setBusy(true)
    // optimistic UI update
    setLocalRideInProgress(true)
    try {
      await nuiSend('tablet:startRide')
    } catch (e) {
      // on error, rollback the optimistic change
      setLocalRideInProgress(false)
      throw e
    } finally {
      setBusy(false)
    }
  }

  const endRide = async () => {
    if (busy || !localRideInProgress) return
    setBusy(true)
    // optimistic UI update
    setLocalRideInProgress(false)
    try {
      await nuiSend('tablet:endRide')
    } catch (e) {
      // rollback on error
      setLocalRideInProgress(true)
      throw e
    } finally {
      setBusy(false)
    }
  }

  const close = async () => {
    if (busy) return
    setBusy(true)
    try {
      await nuiSend('tablet:close')
      onClose()
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="tablet-container" style={{ display: visible ? 'grid' : 'none' }}>
      <div className="tablet-card">
        <div className="tablet-header">
          <div className="tablet-title">Taxi Driver</div>
          <button className="tablet-close" onClick={close} aria-label="Close">✕</button>
        </div>
        <div className="tablet-body">
          {!localRideInProgress ? (
            <button
              className="tablet-action start"
              onClick={startRide}
              disabled={busy}
              aria-label="Start Ride"
            >
              {busy ? 'Starting...' : 'Start Ride'}
            </button>
          ) : (
            <button
              className="tablet-action end"
              onClick={endRide}
              disabled={busy}
              aria-label="End Ride"
            >
              {busy ? 'Ending...' : 'End & Collect'}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
