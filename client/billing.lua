-- Client-side billing UI helpers

-- Presents a non-cancelable payment dialog to the passenger and returns true on confirm
lib.callback.register('qbx_taxijob:client:ConfirmFare', function(amount, driverName)
    local amt = tonumber(amount) or 0
    local header = 'Taxi Ride'
    local content = ('Ride completed.\nFare: $%s\nDriver: %s'):format(tostring(amt), driverName or 'Unknown')
    local alert = lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = false,
        size = 'sm',
        labels = { confirm = 'Pay' }
    })
    return alert == 'confirm'
end)
