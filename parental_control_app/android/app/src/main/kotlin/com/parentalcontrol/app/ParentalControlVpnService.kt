package com.parentalcontrol.app

import android.content.Intent
import android.net.VpnService

/**
 * Minimal [VpnService] so [VpnService.prepare] can show the system VPN consent dialog.
 * Call [establish] only when you implement real tunneling.
 */
class ParentalControlVpnService : VpnService() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }
}
