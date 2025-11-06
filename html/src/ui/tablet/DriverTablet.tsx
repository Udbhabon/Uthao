import React, { useEffect, useState } from 'react'
import { nuiSend } from '../../nui'
import { Button } from '@/components/ui/button'
import { Card } from '@/components/ui/card'

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
      {/* Removed extra Tailwind backdrop/background classes to eliminate large dark rectangle */}
      <Card className="tablet-card border border-border">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <h2 className="font-semibold tracking-wide">Taxi Driver</h2>
          <Button variant="outline" size="sm" className="h-8 w-8 p-0" onClick={close} aria-label="Close">✕</Button>
        </div>
        <div className="p-4 flex flex-col gap-4">
          <div className="flex items-center justify-between gap-6">
            <div className="space-y-1">
              <p className="text-xs text-muted-foreground">Status</p>
              <p className="text-sm font-medium">{localRideInProgress ? 'Ride in progress' : 'Available'}</p>
            </div>
            <div className="space-y-1 text-right">
              <p className="text-xs text-muted-foreground">Live Fare</p>
              <p className="text-lg font-bold text-emerald-500">$0.00</p>
            </div>
          </div>
          <div className="flex flex-wrap gap-3">
            {!localRideInProgress ? (
              <Button onClick={startRide} disabled={busy}>
                {busy ? 'Starting…' : 'Start Ride'}
              </Button>
            ) : (
              <Button onClick={endRide} disabled={busy} variant="destructive">
                {busy ? 'Ending…' : 'End & Collect'}
              </Button>
            )}
            <Button variant="outline" onClick={close}>Close</Button>
          </div>
        </div>
      </Card>
    </div>
  )
}
