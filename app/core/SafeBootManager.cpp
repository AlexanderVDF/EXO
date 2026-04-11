#include "SafeBootManager.h"
#include "LogManager.h"
#include <QDateTime>

// ═══════════════════════════════════════════════════════
//  SafeBootManager — implémentation EXO v30.1
// ═══════════════════════════════════════════════════════

// Services critiques par défaut — le pipeline vocal minimal
const QSet<QString> SafeBootManager::s_defaultCritical = {
    QStringLiteral("orchestrator"),
    QStringLiteral("stt"),
    QStringLiteral("tts"),
    QStringLiteral("vad"),
    QStringLiteral("wakeword"),
    QStringLiteral("memory"),
    QStringLiteral("nlu"),
    QStringLiteral("context"),
    QStringLiteral("planner"),
    QStringLiteral("executor"),
    QStringLiteral("verifier"),
    QStringLiteral("system")
};

SafeBootManager::SafeBootManager(QObject *parent)
    : QObject(parent)
    , m_criticalServices(s_defaultCritical)
{
}

void SafeBootManager::setRegistry(ServiceRegistry *registry)
{
    if (m_registry) {
        disconnect(m_registry, nullptr, this, nullptr);
    }
    m_registry = registry;

    if (m_registry) {
        connect(m_registry, &ServiceRegistry::serviceStateChanged,
                this, &SafeBootManager::onServiceStateChanged);
    }
}

// ── Classification ──────────────────────────────────────

bool SafeBootManager::isCritical(const QString &name) const
{
    return m_criticalServices.contains(name.toLower());
}

// ── Accesseurs ──────────────────────────────────────────

bool SafeBootManager::criticalReady() const
{
    if (!m_registry) return false;
    for (const QString &name : m_criticalServices) {
        if (!m_registry->contains(name)) continue;
        if (m_registry->entry(name).state != Exo::ServiceState::Ready)
            return false;
    }
    return true;
}

int SafeBootManager::criticalReadyCount() const
{
    if (!m_registry) return 0;
    int count = 0;
    for (const QString &name : m_criticalServices) {
        if (!m_registry->contains(name)) continue;
        if (m_registry->entry(name).state == Exo::ServiceState::Ready)
            ++count;
    }
    return count;
}

int SafeBootManager::lazyTotal() const
{
    if (!m_registry) return 0;
    return m_registry->totalServices() - m_criticalServices.size();
}

int SafeBootManager::lazyReadyCount() const
{
    if (!m_registry) return 0;
    int count = 0;
    for (const QString &name : m_registry->serviceNames()) {
        if (m_criticalServices.contains(name)) continue;
        if (m_registry->entry(name).state == Exo::ServiceState::Ready)
            ++count;
    }
    return count;
}

int SafeBootManager::failedCount() const
{
    if (!m_registry) return 0;
    int count = 0;
    for (const QString &name : m_registry->serviceNames()) {
        auto st = m_registry->entry(name).state;
        if (st == Exo::ServiceState::Failed || st == Exo::ServiceState::Crashed)
            ++count;
    }
    return count;
}

QVariantList SafeBootManager::failedServices() const
{
    QVariantList list;
    if (!m_registry) return list;
    for (const QString &name : m_registry->serviceNames()) {
        auto st = m_registry->entry(name).state;
        if (st == Exo::ServiceState::Failed || st == Exo::ServiceState::Crashed) {
            QVariantMap m;
            m[QStringLiteral("name")] = name;
            m[QStringLiteral("state")] = Exo::serviceStateToString(st);
            m[QStringLiteral("critical")] = m_criticalServices.contains(name);
            m[QStringLiteral("port")] = m_registry->entry(name).descriptor.port;
            list.append(m);
        }
    }
    return list;
}

QVariantList SafeBootManager::lazyServices() const
{
    QVariantList list;
    if (!m_registry) return list;
    for (const QString &name : m_registry->serviceNames()) {
        if (m_criticalServices.contains(name)) continue;
        const auto &entry = m_registry->entry(name);
        QVariantMap m;
        m[QStringLiteral("name")] = name;
        m[QStringLiteral("state")] = Exo::serviceStateToString(entry.state);
        m[QStringLiteral("port")] = entry.descriptor.port;
        list.append(m);
    }
    return list;
}

QVariantList SafeBootManager::criticalServices() const
{
    QVariantList list;
    if (!m_registry) return list;
    for (const QString &name : m_registry->serviceNames()) {
        if (!m_criticalServices.contains(name)) continue;
        const auto &entry = m_registry->entry(name);
        QVariantMap m;
        m[QStringLiteral("name")] = name;
        m[QStringLiteral("state")] = Exo::serviceStateToString(entry.state);
        m[QStringLiteral("port")] = entry.descriptor.port;
        list.append(m);
    }
    return list;
}

// ── Slot de surveillance ────────────────────────────────

void SafeBootManager::onServiceStateChanged(const QString &name,
                                             const QString & /*oldState*/,
                                             const QString &newState)
{
    bool isCrit = m_criticalServices.contains(name.toLower());

    // Si un service non critique échoue → activer safe boot
    if (!isCrit && (newState == QLatin1String("failed") || newState == QLatin1String("crashed"))) {
        activateSafeBoot(QStringLiteral("Service non-critique '%1' en %2").arg(name, newState));
    }

    // Si un service critique échoue → log critique mais on continue
    // (le retry policy peut encore le relancer)
    if (isCrit && newState == QLatin1String("failed")) {
        hWarning(exoMain) << "[SafeBoot] ⚠ Service critique" << name << "en échec — retry en cours";
    }

    if (isCrit) {
        emit criticalReadyChanged();
        checkCriticalReady();
    } else {
        emit lazyProgressChanged();
    }

    emit safeBootChanged();
    checkAllNormalized();
}

// ── Vérification des critiques ──────────────────────────

void SafeBootManager::checkCriticalReady()
{
    if (m_criticalEmitted) return;
    if (!criticalReady()) return;

    m_criticalEmitted = true;
    hLog() << "[SafeBoot] ═══ CRITICAL SERVICES READY ═══"
           << criticalReadyCount() << "/" << criticalTotal();

    if (m_safeBootActive) {
        hLog() << "[SafeBoot] Mode Safe Boot actif —"
               << lazyReadyCount() << "/" << lazyTotal() << "services lazy en cours";
    }

    emit safeBootReady();
}

void SafeBootManager::checkAllNormalized()
{
    if (!m_registry) return;

    // Vérifier que tous les services sont Ready
    if (m_registry->allReady()) {
        if (m_safeBootActive) {
            hLog() << "[SafeBoot] ✓ Tous les services normalisés — sortie du mode Safe Boot";
            m_safeBootActive = false;
            emit safeBootChanged();
        }
        emit allServicesNormalized();
    }
}

// ── Activation Safe Boot ────────────────────────────────

void SafeBootManager::activateSafeBoot(const QString &reason)
{
    if (m_safeBootActive) return;

    m_safeBootActive = true;
    hWarning(exoMain) << "[SafeBoot] ═══ MODE SAFE BOOT ACTIVÉ ═══ Raison:" << reason;
    emit safeBootChanged();
}

// ── Rapport diagnostic ──────────────────────────────────

QVariantMap SafeBootManager::diagnosticReport() const
{
    QVariantMap report;
    report[QStringLiteral("timestamp")] = QDateTime::currentDateTime().toString(Qt::ISODate);
    report[QStringLiteral("safeBootActive")] = m_safeBootActive;
    report[QStringLiteral("criticalReady")] = criticalReady();
    report[QStringLiteral("criticalReadyCount")] = criticalReadyCount();
    report[QStringLiteral("criticalTotal")] = criticalTotal();
    report[QStringLiteral("lazyReadyCount")] = lazyReadyCount();
    report[QStringLiteral("lazyTotal")] = lazyTotal();
    report[QStringLiteral("failedCount")] = failedCount();
    report[QStringLiteral("failedServices")] = failedServices();
    report[QStringLiteral("lazyServices")] = lazyServices();
    report[QStringLiteral("criticalServices")] = criticalServices();
    return report;
}
