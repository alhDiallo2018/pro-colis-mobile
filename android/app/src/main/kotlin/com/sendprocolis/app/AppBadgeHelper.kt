package com.sendprocolis.app

import android.content.Context
import android.content.Intent

/**
 * Applique un badge numérique sur l'icône de l'application via les broadcasts
 * propres à chaque launcher.
 *
 * Aucun launcher Android ne se comporte exactement comme un autre : le badge
 * est donc adressé au mieux, launcher par launcher. Chaque tentative est
 * isolée dans un try/catch afin qu'un launcher non supporté (ou une API
 * manquante) ne produise jamais de crash — le badge est alors simplement
 * ignoré, comme sur les launchers qui n'affichent que des « dots » (Pixel).
 */
object AppBadgeHelper {

    private const val BADGE_INTENT_SAMSUNG = "android.intent.action.BADGE_COUNT_UPDATE"
    private const val BADGE_INTENT_SONY = "com.sonyericsson.home.action.UPDATE_BADGE"
    private const val BADGE_INTENT_HTC = "com.htc.launcher.action.SET_NOTIFICATION"
    private const val BADGE_INTENT_LG = "com.lge.launcher.action.UPDATE_BADGE"
    private const val BADGE_INTENT_HUAWEI = "com.huawei.android.launcher.action.CHANGE_BADGE"
    private const val BADGE_INTENT_ZTE = "com.zte.launcher.action.CHANGE_BADGE"
    private const val BADGE_INTENT_OPPO = "com.oppo.unsettledevent"
    private const val BADGE_INTENT_VIVO = "launcher.action.CHANGE_APPLICATION_NOTIFICATION_NUM"

    fun setBadge(context: Context, count: Int) {
        val value = if (count < 0) 0 else count
        val className = launcherClassName(context)
        val packageName = context.packageName

        runCatching { samsung(context, value, className) }
        runCatching { sony(context, value, className) }
        runCatching { htc(context, value, className) }
        runCatching { lg(context, value, className) }
        runCatching { huawei(context, value, className) }
        runCatching { zte(context, value, className) }
        runCatching { oppo(context, value) }
        runCatching { vivo(context, value, className) }
    }

    private fun launcherClassName(context: Context): String {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return intent?.component?.className ?: "${context.packageName}.MainActivity"
    }

    private fun samsung(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_SAMSUNG).apply {
            putExtra("badge_count", count)
            putExtra("badge_count_package_name", context.packageName)
            putExtra("badge_count_class_name", className)
        }
        context.sendBroadcast(intent)
    }

    private fun sony(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_SONY).apply {
            putExtra("com.sonyericsson.home.intent.extra.badge.ACTIVITY_NAME", className)
            putExtra("com.sonyericsson.home.intent.extra.badge.SHOW_MESSAGE", count > 0)
            putExtra("com.sonyericsson.home.intent.extra.badge.MESSAGE", count.toString())
            putExtra("com.sonyericsson.home.intent.extra.badge.PACKAGE_NAME", context.packageName)
        }
        context.sendBroadcast(intent)
    }

    private fun htc(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_HTC).apply {
            putExtra("com.htc.launcher.extra.COMPONENT", "$className")
            putExtra("com.htc.launcher.extra.COUNT", count)
        }
        context.sendBroadcast(intent)
    }

    private fun lg(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_LG).apply {
            putExtra("badge_count", count)
            putExtra("badge_count_package_name", context.packageName)
            putExtra("badge_count_class_name", className)
        }
        context.sendBroadcast(intent)
    }

    private fun huawei(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_HUAWEI).apply {
            putExtra("com.huawei.android.launcher.extra.BADGE_VALUE", count)
            putExtra("com.huawei.android.launcher.extra.BADGE_CLASS", className)
            putExtra("com.huawei.android.launcher.extra.BADGE_PACKAGE", context.packageName)
        }
        context.sendBroadcast(intent)
    }

    private fun zte(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_ZTE).apply {
            putExtra("app_badge_count", count)
            putExtra("app_badge_component_name", className)
        }
        context.sendBroadcast(intent)
    }

    private fun oppo(context: Context, count: Int) {
        val intent = Intent(BADGE_INTENT_OPPO).apply {
            putExtra("packageName", context.packageName)
            putExtra("number", count)
            putExtra("upgradeNumber", count)
        }
        context.sendBroadcast(intent)
    }

    private fun vivo(context: Context, count: Int, className: String) {
        val intent = Intent(BADGE_INTENT_VIVO).apply {
            putExtra("packageName", context.packageName)
            putExtra("className", className)
            putExtra("notificationNum", count)
        }
        context.sendBroadcast(intent)
    }
}
