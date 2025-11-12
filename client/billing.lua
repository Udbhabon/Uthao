-- Client-side billing UI helpers

--[[
    DEPRECATED: This ox_lib alert dialog payment system has been replaced
    by the Customer Tablet UI payment flow. Payment is now handled through
    the NUI interface in CustomerTablet.tsx with better UX.
    
    The payment flow now works as follows:
    1. Server triggers 'qbx_taxijob:client:RideCompleted' event to passenger
    2. Customer tablet UI shows payment screen with fare details
    3. Passenger selects payment method (debit/cash) and clicks Pay/Cancel
    4. Client sends 'customer:confirmPayment' NUI callback
    5. Server processes payment via 'qbx_taxijob:server:ProcessPayment' event
    
    This callback is kept for backwards compatibility but should not be used.
]]--

-- Presents a non-cancelable payment dialog to the passenger and returns true on confirm
lib.callback.register('qbx_taxijob:client:ConfirmFare', function(amount, driverName)
    print('[qbx_taxijob] [WARNING] Legacy ConfirmFare callback called - this should use Customer Tablet UI instead')
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
